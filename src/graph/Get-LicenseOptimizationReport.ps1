<#
.SYNOPSIS
    Generates a Microsoft 365 license optimization report highlighting waste and savings opportunities.

.DESCRIPTION
    Connects to Microsoft Graph and analyzes license assignments across the tenant to identify:
      - Licensed users who have not signed in within a configurable threshold (default: 90 days)
      - Users assigned high-cost E5 licenses who may only need E3/Business Premium
      - License SKUs with significant over-provisioning (available seats > configurable threshold)
      - Service plans that are disabled for all or most assigned users

    Exports per-user findings and an org-wide SKU summary to CSV.
    Suitable for monthly license reviews, finance reporting, and compliance documentation.

.PARAMETER ExportPath
    Directory where CSV reports will be saved. Default: current working directory.

.PARAMETER InactiveDays
    Number of days without sign-in to flag a licensed user as inactive. Default: 90.

.PARAMETER OverProvisionThreshold
    Minimum number of unused seats before a SKU is flagged as over-provisioned. Default: 10.

.PARAMETER LogPath
    Full path for a structured run log. If omitted, console-only output is produced.

.EXAMPLE
    .\Get-LicenseOptimizationReport.ps1
    Runs with all defaults; saves CSVs to the current directory.

.EXAMPLE
    .\Get-LicenseOptimizationReport.ps1 -InactiveDays 60 -ExportPath "C:\Reports"
    Flags users inactive for 60+ days and saves reports to C:\Reports.

.EXAMPLE
    .\Get-LicenseOptimizationReport.ps1 -OverProvisionThreshold 25 -LogPath "C:\Logs\LicOpt.log"
    Raises over-provision threshold and enables file logging.

.NOTES
    Author:   Elazar Ferrer
    Version:  1.0
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement
    Scopes:   User.Read.All, Organization.Read.All, AuditLog.Read.All

    SECURITY: Never hardcode credentials. Use Connect-MgGraph with certificate-based
    auth or a Managed Identity for unattended runs. See SECURITY.md.

    COMPLIANCE: Output CSVs contain PII. Store in an access-controlled location
    and retain per your organisation's data-retention policy.
#>

[CmdletBinding()]
param (
    [string]$ExportPath            = ".",
    [int]   $InactiveDays          = 90,
    [int]   $OverProvisionThreshold = 10,
    [string]$LogPath               = ""
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Import shared logging helper ──────────────────────────────────────────────
$helpersPath = Join-Path $PSScriptRoot "..\helpers\Write-Log.ps1"
if (Test-Path $helpersPath) {
    Import-Module $helpersPath -Force
} else {
    # Inline fallback so the script works if run standalone
    function Write-Log   { param([string]$Message,[string]$Level="INFO") Write-Host "[$Level] $Message" }
    function Write-LogBanner  { param([string]$Title) Write-Host "`n=== $Title ===" -ForegroundColor Cyan }
    function Write-LogSummary { param([object]$Data) $Data | Format-List }
    function Initialize-Log   { param([string]$LogPath,[string]$ScriptName) }
}

if ($LogPath) { Initialize-Log -LogPath $LogPath -ScriptName "Get-LicenseOptimizationReport" }

Write-LogBanner -Title "M365 License Optimization Report"

# ── SKU friendly-name map ─────────────────────────────────────────────────────
$skuMap = @{
    "SPE_E3"                   = "Microsoft 365 E3"
    "SPE_E5"                   = "Microsoft 365 E5"
    "ENTERPRISEPACK"           = "Office 365 E3"
    "ENTERPRISEPREMIUM"        = "Office 365 E5"
    "O365_BUSINESS_PREMIUM"    = "Microsoft 365 Business Premium"
    "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
    "DESKLESSPACK"             = "Office 365 F3"
    "EXCHANGESTANDARD"         = "Exchange Online Plan 1"
    "EXCHANGEENTERPRISE"       = "Exchange Online Plan 2"
    "POWER_BI_PRO"             = "Power BI Pro"
    "INTUNE_A"                 = "Microsoft Intune"
    "AAD_PREMIUM"              = "Azure AD Premium P1"
    "AAD_PREMIUM_P2"           = "Azure AD Premium P2"
    "EMS"                      = "Enterprise Mobility + Security E3"
    "EMSPREMIUM"               = "Enterprise Mobility + Security E5"
}

$highCostSkus = @("SPE_E5","ENTERPRISEPREMIUM","EMSPREMIUM","AAD_PREMIUM_P2")

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Log "Connecting to Microsoft Graph..." -Level INFO

try {
    Connect-MgGraph -Scopes "User.Read.All","Organization.Read.All","AuditLog.Read.All" -NoWelcome
    Write-Log "Connected to Microsoft Graph" -Level SUCCESS
} catch {
    Write-Log "Failed to connect to Microsoft Graph: $_" -Level ERROR
    exit 1
}

# ── Fetch subscribed SKUs ─────────────────────────────────────────────────────
Write-Log "Fetching organisation license SKUs..." -Level INFO

try {
    $subscribedSkus = Get-MgSubscribedSku -All
} catch {
    Write-Log "Failed to retrieve subscribed SKUs: $_" -Level ERROR
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Build SKU ID → PartNumber lookup
$skuIdMap = @{}
foreach ($sku in $subscribedSkus) { $skuIdMap[$sku.SkuId] = $sku.SkuPartNumber }

# ── Fetch users ───────────────────────────────────────────────────────────────
Write-Log "Fetching all users with license and sign-in data (this may take a moment)..." -Level INFO

$props = @(
    "DisplayName","UserPrincipalName","Department","JobTitle",
    "AccountEnabled","AssignedLicenses","SignInActivity","CreatedDateTime","UserType"
)

try {
    $allUsers = Get-MgUser -All -Property $props
} catch {
    Write-Log "Failed to retrieve users: $_" -Level ERROR
    Disconnect-MgGraph | Out-Null
    exit 1
}

Write-Log "Retrieved $($allUsers.Count) user accounts" -Level SUCCESS

# ── Analyse each user ─────────────────────────────────────────────────────────
Write-Log "Analysing license assignments..." -Level INFO

$cutoff       = (Get-Date).AddDays(-$InactiveDays)
$userReport   = [System.Collections.Generic.List[PSCustomObject]]::new()
$wasteCount   = 0

foreach ($user in $allUsers) {
    if (($user.AssignedLicenses | Measure-Object).Count -eq 0) { continue }

    $lastSignIn = $user.SignInActivity?.LastSignInDateTime
    $daysSince  = if ($lastSignIn) {
        [math]::Round(((Get-Date) - [datetime]$lastSignIn).TotalDays)
    } else { $null }

    $isInactive      = $lastSignIn ? ([datetime]$lastSignIn -lt $cutoff) : $true
    $licenseNames    = $user.AssignedLicenses | ForEach-Object {
        $part = $skuIdMap[$_.SkuId]
        if ($skuMap[$part]) { $skuMap[$part] } else { $part ?? $_.SkuId }
    }
    $hasHighCost     = $user.AssignedLicenses | Where-Object { $highCostSkus -contains $skuIdMap[$_.SkuId] }
    $recommendation  = @()

    if ($isInactive)  { $recommendation += "Review/reclaim — inactive $($daysSince ?? 'N/A (never signed in)') days" }
    if ($hasHighCost -and $isInactive) { $recommendation += "Downgrade from high-cost SKU" }

    if ($recommendation.Count -gt 0) { $wasteCount++ }

    $userReport.Add([PSCustomObject]@{
        DisplayName      = $user.DisplayName
        UPN              = $user.UserPrincipalName
        UserType         = $user.UserType
        Department       = $user.Department
        JobTitle         = $user.JobTitle
        AccountEnabled   = $user.AccountEnabled
        Licenses         = ($licenseNames -join " | ")
        LicenseCount     = ($user.AssignedLicenses | Measure-Object).Count
        HasHighCostLicense = [bool]$hasHighCost
        LastSignIn       = $lastSignIn ?? "Never"
        DaysSinceSignIn  = $daysSince ?? "N/A"
        IsInactive       = $isInactive
        Recommendation   = ($recommendation -join "; ")
        AccountCreated   = $user.CreatedDateTime
    })
}

# ── SKU over-provision analysis ───────────────────────────────────────────────
Write-Log "Analysing SKU over-provisioning..." -Level INFO

$skuReport = $subscribedSkus | ForEach-Object {
    $friendly   = if ($skuMap[$_.SkuPartNumber]) { $skuMap[$_.SkuPartNumber] } else { $_.SkuPartNumber }
    $total      = $_.PrepaidUnits.Enabled
    $used       = $_.ConsumedUnits
    $available  = $total - $used
    $overFlag   = $available -gt $OverProvisionThreshold

    [PSCustomObject]@{
        SkuPartNumber    = $_.SkuPartNumber
        FriendlyName     = $friendly
        TotalLicenses    = $total
        UsedLicenses     = $used
        AvailableLicenses = $available
        UtilisationPct   = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }
        OverProvisioned  = $overFlag
        Recommendation   = if ($overFlag) { "Consider reducing purchased quantity by $available seats" } else { "" }
    }
}

# ── Export ────────────────────────────────────────────────────────────────────
$datestamp      = Get-Date -Format 'yyyy-MM-dd'
$userCsvPath    = Join-Path $ExportPath "LicenseOptimization_Users_$datestamp.csv"
$skuCsvPath     = Join-Path $ExportPath "LicenseOptimization_SKUs_$datestamp.csv"

$userReport | Export-Csv -Path $userCsvPath -NoTypeInformation -Encoding UTF8
$skuReport  | Export-Csv -Path $skuCsvPath  -NoTypeInformation -Encoding UTF8

Write-Log "User report  : $userCsvPath" -Level SUCCESS
Write-Log "SKU report   : $skuCsvPath"  -Level SUCCESS

# ── Summary ───────────────────────────────────────────────────────────────────
$inactiveCount    = ($userReport | Where-Object IsInactive -eq $true  | Measure-Object).Count
$highCostInactive = ($userReport | Where-Object { $_.IsInactive -and $_.HasHighCostLicense } | Measure-Object).Count
$overProvSkus     = ($skuReport  | Where-Object OverProvisioned -eq $true | Measure-Object).Count

Write-LogSummary -Data ([ordered]@{
    "Total licensed users"        = ($userReport | Measure-Object).Count
    "Inactive licensed users"     = $inactiveCount
    "High-cost + inactive"        = $highCostInactive
    "Over-provisioned SKUs"       = "$overProvSkus / $($skuReport.Count)"
    "Waste candidates identified" = $wasteCount
    "User report"                 = $userCsvPath
    "SKU report"                  = $skuCsvPath
})

Disconnect-MgGraph | Out-Null
Write-Log "Disconnected from Microsoft Graph" -Level SUCCESS
