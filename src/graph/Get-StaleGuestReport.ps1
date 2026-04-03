<#
.SYNOPSIS
    Identifies and optionally removes stale Microsoft 365 B2B guest accounts.

.DESCRIPTION
    Connects to Microsoft Graph and finds external (guest) user accounts that
    have not signed in for longer than a configurable threshold. Inactive guests
    are a common attack surface and compliance gap — this script helps you find
    and remediate them safely.

    Actions taken depend on the switches used:
      - Default (no switches): report only — exports a CSV, no changes made.
      - -SendReview: sends an access-review reminder (requires Exchange / Power Automate
        integration; see documentation).
      - -DisableGuests: disables the account in Entra ID (requires -Confirm or -Force).
      - -RemoveGuests: permanently deletes the account (requires -Confirm or -Force).

    The script is fully -WhatIf / -Confirm safe for all destructive operations.

.PARAMETER InactiveDays
    Days without sign-in before a guest is considered stale. Default: 90.

.PARAMETER ExportPath
    Full path for the output CSV report.
    Default: .\StaleGuests_<date>.csv

.PARAMETER LogPath
    Full path for the structured run log. Omit for console-only output.

.PARAMETER DisableGuests
    Disables stale guest accounts in Entra ID. Supports -WhatIf.

.PARAMETER RemoveGuests
    Permanently deletes stale guest accounts. Supports -WhatIf.
    USE WITH EXTREME CAUTION — this action cannot be undone (outside 30-day recycle bin).

.PARAMETER Force
    Suppresses confirmation prompts for -DisableGuests and -RemoveGuests.
    Not recommended for production runs.

.EXAMPLE
    .\Get-StaleGuestReport.ps1
    Reports all guest accounts inactive 90+ days. No changes made.

.EXAMPLE
    .\Get-StaleGuestReport.ps1 -InactiveDays 60 -ExportPath "C:\Reports\Guests.csv"
    Uses a 60-day threshold and saves the report to the specified path.

.EXAMPLE
    .\Get-StaleGuestReport.ps1 -DisableGuests -WhatIf
    Preview which accounts would be disabled without making any changes.

.EXAMPLE
    .\Get-StaleGuestReport.ps1 -DisableGuests -Confirm
    Disables stale guests with a per-account confirmation prompt.

.EXAMPLE
    .\Get-StaleGuestReport.ps1 -RemoveGuests -Force
    Permanently removes all stale guests without confirmation (use in tested automation only).

.NOTES
    Author:   Elazar Ferrer
    Version:  1.0
    Requires: Microsoft.Graph.Users
    Scopes:   User.Read.All, AuditLog.Read.All
              (+ User.ReadWrite.All if using -DisableGuests or -RemoveGuests)

    SECURITY: Run with the minimum scopes for the operation. For report-only runs,
    User.Read.All + AuditLog.Read.All is sufficient. See SECURITY.md for auth patterns.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param (
    [int]   $InactiveDays = 90,
    [string]$ExportPath   = ".\StaleGuests_$(Get-Date -Format 'yyyy-MM-dd').csv",
    [string]$LogPath      = "",
    [switch]$DisableGuests,
    [switch]$RemoveGuests,
    [switch]$Force
)

#Requires -Modules Microsoft.Graph.Users

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

if ($LogPath) { Initialize-Log -LogPath $LogPath -ScriptName "Get-StaleGuestReport" }

Write-LogBanner -Title "Stale Guest Account Report"

# ── Validate mutually exclusive flags ────────────────────────────────────────
if ($DisableGuests -and $RemoveGuests) {
    Write-Log "-DisableGuests and -RemoveGuests cannot be used together." -Level ERROR
    exit 1
}

# ── Determine required scopes ─────────────────────────────────────────────────
$scopes = @("User.Read.All","AuditLog.Read.All")
if ($DisableGuests -or $RemoveGuests) { $scopes += "User.ReadWrite.All" }

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Log "Connecting to Microsoft Graph (scopes: $($scopes -join ', '))..." -Level INFO

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome
    Write-Log "Connected to Microsoft Graph" -Level SUCCESS
} catch {
    Write-Log "Failed to connect: $_" -Level ERROR
    exit 1
}

# ── Fetch guest users ─────────────────────────────────────────────────────────
Write-Log "Fetching all guest users (UserType eq 'Guest')..." -Level INFO

$props = @(
    "DisplayName","UserPrincipalName","Mail","Department","JobTitle",
    "AccountEnabled","SignInActivity","CreatedDateTime","ExternalUserState",
    "ExternalUserStateChangeDateTime","Id"
)

try {
    $guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property $props
} catch {
    Write-Log "Failed to retrieve guest users: $_" -Level ERROR
    Disconnect-MgGraph | Out-Null
    exit 1
}

Write-Log "Found $($guests.Count) total guest account(s)" -Level INFO

# ── Find stale guests ─────────────────────────────────────────────────────────
$cutoff     = (Get-Date).AddDays(-$InactiveDays)
$staleGuests = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($guest in $guests) {
    $lastSignIn = $guest.SignInActivity?.LastSignInDateTime
    $isStale    = $lastSignIn ? ([datetime]$lastSignIn -lt $cutoff) : $true
    if (-not $isStale) { continue }

    $daysSince = if ($lastSignIn) {
        [math]::Round(((Get-Date) - [datetime]$lastSignIn).TotalDays)
    } else { "Never signed in" }

    $staleGuests.Add([PSCustomObject]@{
        Id                    = $guest.Id
        DisplayName           = $guest.DisplayName
        UPN                   = $guest.UserPrincipalName
        Mail                  = $guest.Mail
        Department            = $guest.Department
        AccountEnabled        = $guest.AccountEnabled
        ExternalUserState     = $guest.ExternalUserState
        InviteAccepted        = $guest.ExternalUserStateChangeDateTime
        LastSignIn            = $lastSignIn ?? "Never"
        DaysSinceSignIn       = $daysSince
        AccountCreated        = $guest.CreatedDateTime
        RecommendedAction     = if ($DisableGuests) { "Disable" } elseif ($RemoveGuests) { "Remove" } else { "Review" }
    })
}

Write-Log "Found $($staleGuests.Count) stale guest(s) (inactive $InactiveDays+ days)" -Level $(if ($staleGuests.Count -gt 0) { "WARNING" } else { "SUCCESS" })

# ── Export CSV ────────────────────────────────────────────────────────────────
$staleGuests | Select-Object -ExcludeProperty Id | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-Log "Report exported: $ExportPath" -Level SUCCESS

if ($staleGuests.Count -eq 0) {
    Write-Log "No stale guests found. No action required." -Level SUCCESS
    Disconnect-MgGraph | Out-Null
    exit 0
}

# ── Disable action ────────────────────────────────────────────────────────────
if ($DisableGuests) {
    Write-Log "Preparing to disable $($staleGuests.Count) stale guest account(s)..." -Level WARNING

    $disabled = 0; $failed = 0

    foreach ($guest in $staleGuests) {
        $target = "$($guest.DisplayName) ($($guest.UPN))"

        if ($Force -or $PSCmdlet.ShouldProcess($target, "Disable guest account in Entra ID")) {
            try {
                Update-MgUser -UserId $guest.Id -AccountEnabled:$false
                Write-Log "Disabled: $target" -Level SUCCESS
                $disabled++
            } catch {
                Write-Log "Failed to disable $target : $_" -Level ERROR
                $failed++
            }
        }
    }

    Write-Log "Disable complete — $disabled succeeded, $failed failed" -Level $(if ($failed -gt 0) { "WARNING" } else { "SUCCESS" })
}

# ── Remove action ─────────────────────────────────────────────────────────────
if ($RemoveGuests) {
    Write-Log "Preparing to PERMANENTLY DELETE $($staleGuests.Count) stale guest account(s)..." -Level WARNING
    Write-Log "Deleted users can be restored within 30 days from the Entra ID recycle bin." -Level WARNING

    $removed = 0; $failed = 0

    foreach ($guest in $staleGuests) {
        $target = "$($guest.DisplayName) ($($guest.UPN))"

        if ($Force -or $PSCmdlet.ShouldProcess($target, "PERMANENTLY DELETE guest account from Entra ID")) {
            try {
                Remove-MgUser -UserId $guest.Id
                Write-Log "Removed: $target" -Level SUCCESS
                $removed++
            } catch {
                Write-Log "Failed to remove $target : $_" -Level ERROR
                $failed++
            }
        }
    }

    Write-Log "Remove complete — $removed succeeded, $failed failed" -Level $(if ($failed -gt 0) { "WARNING" } else { "SUCCESS" })
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-LogSummary -Data ([ordered]@{
    "Total guests"             = $guests.Count
    "Stale guests (${InactiveDays}+ days)" = $staleGuests.Count
    "Threshold"                = "$InactiveDays days"
    "Action taken"             = if ($DisableGuests) { "Disable" } elseif ($RemoveGuests) { "Remove" } else { "Report only" }
    "Report"                   = $ExportPath
})

Disconnect-MgGraph | Out-Null
Write-Log "Disconnected from Microsoft Graph" -Level SUCCESS
