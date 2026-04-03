<#
.SYNOPSIS
    Exports all Conditional Access policies from Microsoft Entra ID for audit and documentation.

.DESCRIPTION
    Connects to Microsoft Graph and retrieves every Conditional Access policy in the tenant,
    including state (enabled/disabled/report-only), assignments, grant controls, and session
    controls. Exports to CSV for runbook documentation, compliance evidence, and change audits.

    This script is read-only — it makes no changes to any policy.

    Common use cases:
      - Pre-change baseline before modifying Conditional Access
      - Evidence artifact for SOC 2 / ISO 27001 / NIST CSF access-control reviews
      - Monthly CA policy inventory to detect unexpected additions or modifications
      - Comparing policy state before and after a change window

.PARAMETER ExportPath
    Full path for the output CSV report.
    Default: .\ConditionalAccessPolicies_<date>.csv

.PARAMETER ExportJson
    Also exports the raw policy JSON to a companion .json file for full fidelity archival.

.PARAMETER LogPath
    Full path for the structured run log. Omit for console-only output.

.PARAMETER IncludeReportOnly
    Include policies in 'Report-only' state (enabled for logging but not enforced).
    Default: $true (all policies are exported regardless of state).

.EXAMPLE
    .\Export-ConditionalAccessPolicies.ps1
    Exports all CA policies to CSV in the current directory.

.EXAMPLE
    .\Export-ConditionalAccessPolicies.ps1 -ExportPath "C:\Reports\CA_Audit.csv" -ExportJson
    Exports CSV + companion JSON for full-fidelity archival.

.EXAMPLE
    .\Export-ConditionalAccessPolicies.ps1 -LogPath "C:\Logs\CA_Audit.log"
    Exports with file logging enabled.

.NOTES
    Author:   Elazar Ferrer
    Version:  1.0
    Requires: Microsoft.Graph.Identity.SignIns
    Scopes:   Policy.Read.All

    SECURITY: This script is read-only. Policy.Read.All is sufficient.
    Do not grant Policy.ReadWrite.ConditionalAccess unless you intend to modify policies.
    See SECURITY.md for authentication guidance.
#>

[CmdletBinding()]
param (
    [string]$ExportPath       = ".\ConditionalAccessPolicies_$(Get-Date -Format 'yyyy-MM-dd').csv",
    [switch]$ExportJson,
    [string]$LogPath          = "",
    [bool]  $IncludeReportOnly = $true
)

#Requires -Modules Microsoft.Graph.Identity.SignIns

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Import shared logging helper ──────────────────────────────────────────────
$helpersPath = Join-Path $PSScriptRoot "..\helpers\Write-Log.ps1"
if (Test-Path $helpersPath) {
    Import-Module $helpersPath -Force
} else {
    function Write-Log   { param([string]$Message,[string]$Level="INFO") Write-Host "[$Level] $Message" }
    function Write-LogBanner  { param([string]$Title) Write-Host "`n=== $Title ===" -ForegroundColor Cyan }
    function Write-LogSummary { param([object]$Data) $Data | Format-List }
    function Initialize-Log   { param([string]$LogPath,[string]$ScriptName) }
}

if ($LogPath) { Initialize-Log -LogPath $LogPath -ScriptName "Export-ConditionalAccessPolicies" }

Write-LogBanner -Title "Conditional Access Policy Audit"

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Log "Connecting to Microsoft Graph (scope: Policy.Read.All)..." -Level INFO

try {
    Connect-MgGraph -Scopes "Policy.Read.All" -NoWelcome
    Write-Log "Connected to Microsoft Graph" -Level SUCCESS
} catch {
    Write-Log "Failed to connect: $_" -Level ERROR
    exit 1
}

# ── Fetch CA policies ─────────────────────────────────────────────────────────
Write-Log "Retrieving Conditional Access policies..." -Level INFO

try {
    $policies = Get-MgIdentityConditionalAccessPolicy -All
} catch {
    Write-Log "Failed to retrieve Conditional Access policies: $_" -Level ERROR
    Disconnect-MgGraph | Out-Null
    exit 1
}

Write-Log "Retrieved $($policies.Count) Conditional Access policy/policies" -Level SUCCESS

# ── Helper: expand assignments ────────────────────────────────────────────────
function Expand-IdList {
    param([object[]]$Items)
    if (-not $Items -or $Items.Count -eq 0) { return "All" }
    return ($Items | ForEach-Object {
        if ($_ -is [string]) { $_ }
        elseif ($_.AdditionalProperties?.displayName) { $_.AdditionalProperties.displayName }
        else { $_.Id ?? $_ }
    }) -join " | "
}

# ── Process policies ──────────────────────────────────────────────────────────
$report = foreach ($policy in $policies) {

    # Skip disabled policies if caller only wants active ones
    if (-not $IncludeReportOnly -and $policy.State -eq "enabledForReportingButNotEnforced") { continue }

    $conditions  = $policy.Conditions
    $grantControls = $policy.GrantControls
    $sessionControls = $policy.SessionControls

    # Users
    $includeUsers  = Expand-IdList $conditions.Users.IncludeUsers
    $excludeUsers  = Expand-IdList $conditions.Users.ExcludeUsers
    $includeGroups = Expand-IdList $conditions.Users.IncludeGroups
    $excludeGroups = Expand-IdList $conditions.Users.ExcludeGroups
    $includeRoles  = Expand-IdList $conditions.Users.IncludeRoles

    # Apps
    $includeApps = Expand-IdList $conditions.Applications.IncludeApplications
    $excludeApps = Expand-IdList $conditions.Applications.ExcludeApplications

    # Platforms & Locations
    $includePlatforms = if ($conditions.Platforms.IncludePlatforms) { $conditions.Platforms.IncludePlatforms -join " | " } else { "Any" }
    $includeLocations = if ($conditions.Locations.IncludeLocations) { $conditions.Locations.IncludeLocations -join " | " } else { "Any" }
    $excludeLocations = if ($conditions.Locations.ExcludeLocations) { $conditions.Locations.ExcludeLocations -join " | " } else { "None" }

    # Grant controls
    $operator       = $grantControls?.Operator ?? "N/A"
    $builtInCtrls   = if ($grantControls?.BuiltInControls) { $grantControls.BuiltInControls -join " | " } else { "None" }
    $customAuthFact = if ($grantControls?.CustomAuthenticationFactors) { $grantControls.CustomAuthenticationFactors -join " | " } else { "None" }

    # Session controls
    $signInFreq = if ($sessionControls?.SignInFrequency) {
        "$($sessionControls.SignInFrequency.Value) $($sessionControls.SignInFrequency.Type)"
    } else { "Not set" }
    $persistBrowser = $sessionControls?.PersistentBrowser?.Mode ?? "Not set"
    $appRestrictions = if ($sessionControls?.ApplicationEnforcedRestrictions?.IsEnabled) { "Enabled" } else { "Not set" }
    $caAppControl    = $sessionControls?.CloudAppSecurity?.CloudAppSecurityType ?? "Not set"

    [PSCustomObject]@{
        PolicyId              = $policy.Id
        PolicyName            = $policy.DisplayName
        State                 = $policy.State
        CreatedDateTime       = $policy.CreatedDateTime
        ModifiedDateTime      = $policy.ModifiedDateTime
        IncludeUsers          = $includeUsers
        ExcludeUsers          = $excludeUsers
        IncludeGroups         = $includeGroups
        ExcludeGroups         = $excludeGroups
        IncludeRoles          = $includeRoles
        IncludeApplications   = $includeApps
        ExcludeApplications   = $excludeApps
        IncludePlatforms      = $includePlatforms
        IncludeLocations      = $includeLocations
        ExcludeLocations      = $excludeLocations
        GrantOperator         = $operator
        GrantBuiltInControls  = $builtInCtrls
        GrantCustomFactors    = $customAuthFact
        SessionSignInFrequency = $signInFreq
        SessionPersistentBrowser = $persistBrowser
        SessionAppRestrictions = $appRestrictions
        SessionCAAppControl   = $caAppControl
    }
}

# ── Export CSV ────────────────────────────────────────────────────────────────
$report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-Log "CSV report exported: $ExportPath" -Level SUCCESS

# ── Optional JSON export ──────────────────────────────────────────────────────
if ($ExportJson) {
    $jsonPath = [System.IO.Path]::ChangeExtension($ExportPath, ".json")
    $policies | ConvertTo-Json -Depth 20 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Log "JSON archive exported: $jsonPath" -Level SUCCESS
}

# ── Policy state breakdown ────────────────────────────────────────────────────
$enabled      = ($report | Where-Object State -eq "enabled"                           | Measure-Object).Count
$disabled     = ($report | Where-Object State -eq "disabled"                          | Measure-Object).Count
$reportOnly   = ($report | Where-Object State -eq "enabledForReportingButNotEnforced" | Measure-Object).Count

Write-LogSummary -Data ([ordered]@{
    "Total policies"    = $policies.Count
    "Enabled"           = $enabled
    "Report-only"       = $reportOnly
    "Disabled"          = $disabled
    "CSV report"        = $ExportPath
    "JSON archive"      = if ($ExportJson) { [System.IO.Path]::ChangeExtension($ExportPath,".json") } else { "Not generated" }
})

Disconnect-MgGraph | Out-Null
Write-Log "Disconnected from Microsoft Graph" -Level SUCCESS
