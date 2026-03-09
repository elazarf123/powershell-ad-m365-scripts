<#
.SYNOPSIS
    Exports a detailed Microsoft 365 license assignment report for all users.

.DESCRIPTION
    Connects to Microsoft Graph and pulls all licensed M365 users, their
    assigned SKUs, service plan status, and last sign-in. Exports to CSV
    for license auditing, compliance reporting, and cost optimization.
    Useful in environments requiring license accountability (HIPAA, DoD, SOC2).

.PARAMETER ExportPath
    Path to export the CSV report. Default: .\M365_LicenseReport_<date>.csv

.PARAMETER ShowUnlicensed
    Include users with no licenses assigned in the report.

.EXAMPLE
    .\Get-M365LicenseReport.ps1
    Exports all licensed users to CSV with default filename.

.EXAMPLE
    .\Get-M365LicenseReport.ps1 -ShowUnlicensed -ExportPath "C:\Reports\Licenses.csv"
    Includes unlicensed users and saves to specified path.

.NOTES
    Author:  Elazar Ferrer
    Version: 1.0
    Requires: Microsoft.Graph PowerShell SDK
    Permissions: User.Read.All, Organization.Read.All (Graph API)
#>

[CmdletBinding()]
param (
    [string]$ExportPath = ".\M365_LicenseReport_$(Get-Date -Format 'yyyy-MM-dd').csv",
    [switch]$ShowUnlicensed
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       M365 License Audit Report          ║" -ForegroundColor Cyan
Write-Host "║          Elazar Ferrer | EF_SYS          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ── SKU Friendly Name Map ─────────────────────────────────────────────────────
# Maps Microsoft's cryptic SKU names to human-readable license names
$skuMap = @{
    "SPE_E3"                    = "Microsoft 365 E3"
    "SPE_E5"                    = "Microsoft 365 E5"
    "ENTERPRISEPACK"            = "Office 365 E3"
    "ENTERPRISEPREMIUM"         = "Office 365 E5"
    "O365_BUSINESS_PREMIUM"     = "Microsoft 365 Business Premium"
    "O365_BUSINESS_ESSENTIALS"  = "Microsoft 365 Business Basic"
    "DESKLESSPACK"              = "Office 365 F3"
    "EXCHANGESTANDARD"          = "Exchange Online Plan 1"
    "EXCHANGEENTERPRISE"        = "Exchange Online Plan 2"
    "TEAMS_EXPLORATORY"         = "Teams Exploratory"
    "POWER_BI_PRO"              = "Power BI Pro"
    "INTUNE_A"                  = "Microsoft Intune"
    "AAD_PREMIUM"               = "Azure AD Premium P1"
    "AAD_PREMIUM_P2"            = "Azure AD Premium P2"
    "EMS"                       = "Enterprise Mobility + Security E3"
    "EMSPREMIUM"                = "Enterprise Mobility + Security E5"
}

# ── Connect to Graph ──────────────────────────────────────────────────────────
Write-Host "[*] Connecting to Microsoft Graph..." -ForegroundColor Yellow

try {
    Connect-MgGraph -Scopes "User.Read.All", "Organization.Read.All" -NoWelcome
    Write-Host "[+] Connected to Microsoft Graph`n" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to connect: $_" -ForegroundColor Red
    exit 1
}

# ── Get Org SKU totals ────────────────────────────────────────────────────────
Write-Host "[*] Fetching organization license totals..." -ForegroundColor Yellow

$orgSkus = Get-MgSubscribedSku | Select-Object SkuPartNumber,
    @{N='TotalLicenses';  E={$_.PrepaidUnits.Enabled}},
    @{N='UsedLicenses';   E={$_.ConsumedUnits}},
    @{N='AvailableLicenses'; E={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}}

Write-Host "`n[*] Organization License Summary:" -ForegroundColor Cyan
$orgSkus | ForEach-Object {
    $friendly = if ($skuMap[$_.SkuPartNumber]) { $skuMap[$_.SkuPartNumber] } else { $_.SkuPartNumber }
    Write-Host "  $friendly : $($_.UsedLicenses)/$($_.TotalLicenses) used ($($_.AvailableLicenses) available)"
}

# ── Get All Users ─────────────────────────────────────────────────────────────
Write-Host "`n[*] Pulling user license assignments..." -ForegroundColor Yellow

$properties = @(
    "DisplayName", "UserPrincipalName", "Department", "JobTitle",
    "AccountEnabled", "AssignedLicenses", "LicenseAssignmentStates",
    "SignInActivity", "CreatedDateTime", "UsageLocation"
)

$allUsers = Get-MgUser -All -Property $properties

$report = foreach ($user in $allUsers) {

    $isLicensed = ($user.AssignedLicenses | Measure-Object).Count -gt 0

    if (-not $isLicensed -and -not $ShowUnlicensed) { continue }

    $licenseNames = if ($isLicensed) {
        $user.AssignedLicenses | ForEach-Object {
            $sku = $orgSkus | Where-Object { $_.SkuId -eq $_.SkuId } | Select-Object -First 1
            $partNum = (Get-MgSubscribedSku | Where-Object { $_.SkuId -eq $_.SkuId }).SkuPartNumber
            if ($skuMap[$partNum]) { $skuMap[$partNum] } else { $partNum }
        }
    } else { @("None") }

    $lastSignIn = if ($user.SignInActivity.LastSignInDateTime) {
        $user.SignInActivity.LastSignInDateTime
    } else { "Never" }

    [PSCustomObject]@{
        DisplayName        = $user.DisplayName
        UPN                = $user.UserPrincipalName
        Department         = $user.Department
        JobTitle           = $user.JobTitle
        AccountEnabled     = $user.AccountEnabled
        Licensed           = $isLicensed
        Licenses           = ($licenseNames -join " | ")
        LicenseCount       = ($user.AssignedLicenses | Measure-Object).Count
        UsageLocation      = $user.UsageLocation
        LastSignIn         = $lastSignIn
        AccountCreated     = $user.CreatedDateTime
    }
}

# ── Export ────────────────────────────────────────────────────────────────────
$report | Export-Csv -Path $ExportPath -NoTypeInformation

$licensedCount   = ($report | Where-Object { $_.Licensed -eq $true }  | Measure-Object).Count
$unlicensedCount = ($report | Where-Object { $_.Licensed -eq $false } | Measure-Object).Count

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n══════════════ SUMMARY ══════════════" -ForegroundColor Cyan
Write-Host "  Licensed users   : $licensedCount"
Write-Host "  Unlicensed users : $unlicensedCount"
Write-Host "  Report saved to  : $ExportPath"
Write-Host "════════════════════════════════════`n" -ForegroundColor Cyan

Disconnect-MgGraph | Out-Null
Write-Host "[+] Disconnected from Microsoft Graph." -ForegroundColor Green
