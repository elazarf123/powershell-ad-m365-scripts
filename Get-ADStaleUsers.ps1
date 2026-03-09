<#
.SYNOPSIS
    Finds and reports Active Directory user accounts inactive for 90+ days.

.DESCRIPTION
    Queries Active Directory for user accounts that have not logged in within
    a specified number of days (default: 90). Outputs a CSV report and console
    summary. Useful for identifying stale accounts that pose a security risk
    in compliance environments (HIPAA, NIST, DoD).

.PARAMETER DaysInactive
    Number of days since last logon to consider an account stale. Default: 90.

.PARAMETER ExportPath
    Path to export the CSV report. Default: .\StaleUsers_<date>.csv

.PARAMETER DisableAccounts
    Switch to automatically disable found stale accounts. Use with caution.

.EXAMPLE
    .\Get-ADStaleUsers.ps1
    Runs with defaults - finds accounts inactive 90+ days, exports CSV.

.EXAMPLE
    .\Get-ADStaleUsers.ps1 -DaysInactive 60 -ExportPath "C:\Reports\Stale.csv"
    Finds accounts inactive 60+ days, saves to specified path.

.NOTES
    Author:  Elazar Ferrer
    Version: 1.0
    Requires: ActiveDirectory module, Domain Admin or delegated read rights
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [int]$DaysInactive = 90,
    [string]$ExportPath = ".\StaleUsers_$(Get-Date -Format 'yyyy-MM-dd').csv",
    [switch]$DisableAccounts
)

#Requires -Module ActiveDirectory

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       AD Stale User Account Finder       ║" -ForegroundColor Cyan
Write-Host "║          Elazar Ferrer | EF_SYS          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ── Variables ─────────────────────────────────────────────────────────────────
$cutoffDate   = (Get-Date).AddDays(-$DaysInactive)
$domainName   = (Get-ADDomain).DNSRoot
$reportTime   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "[*] Domain       : $domainName" -ForegroundColor Yellow
Write-Host "[*] Cutoff Date  : $($cutoffDate.ToString('yyyy-MM-dd')) ($DaysInactive days)" -ForegroundColor Yellow
Write-Host "[*] Report Time  : $reportTime`n" -ForegroundColor Yellow

# ── Query AD ──────────────────────────────────────────────────────────────────
Write-Host "[*] Querying Active Directory..." -ForegroundColor Cyan

try {
    $staleUsers = Get-ADUser -Filter {
        LastLogonDate -lt $cutoffDate -and Enabled -eq $true
    } -Properties LastLogonDate, PasswordLastSet, Department, Title, Manager, DistinguishedName |
    Select-Object `
        @{N='Username';       E={$_.SamAccountName}},
        @{N='DisplayName';    E={$_.Name}},
        @{N='Department';     E={$_.Department}},
        @{N='Title';          E={$_.Title}},
        @{N='LastLogonDate';  E={if ($_.LastLogonDate) {$_.LastLogonDate} else {"Never"}}},
        @{N='PasswordLastSet';E={$_.PasswordLastSet}},
        @{N='Manager';        E={if ($_.Manager) {(Get-ADUser $_.Manager).Name} else {"N/A"}}},
        @{N='OU';             E={($_.DistinguishedName -split ',',2)[1]}},
        @{N='DaysSinceLogon'; E={
            if ($_.LastLogonDate) {
                [math]::Round(((Get-Date) - $_.LastLogonDate).TotalDays)
            } else { "N/A" }
        }}
} catch {
    Write-Host "[!] Error querying AD: $_" -ForegroundColor Red
    exit 1
}

# ── Results ───────────────────────────────────────────────────────────────────
$count = ($staleUsers | Measure-Object).Count

if ($count -eq 0) {
    Write-Host "[+] No stale accounts found. Domain is clean." -ForegroundColor Green
    exit 0
}

Write-Host "[!] Found $count stale user account(s):`n" -ForegroundColor Red

$staleUsers | Format-Table Username, DisplayName, Department, LastLogonDate, DaysSinceLogon -AutoSize

# ── Export CSV ────────────────────────────────────────────────────────────────
$staleUsers | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "`n[+] Report exported to: $ExportPath" -ForegroundColor Green

# ── Optional Disable ──────────────────────────────────────────────────────────
if ($DisableAccounts) {
    Write-Host "`n[!] -DisableAccounts switch detected. Disabling accounts..." -ForegroundColor Yellow
    foreach ($user in $staleUsers) {
        if ($PSCmdlet.ShouldProcess($user.Username, "Disable AD Account")) {
            try {
                Disable-ADAccount -Identity $user.Username
                Write-Host "  [+] Disabled: $($user.Username)" -ForegroundColor Green
            } catch {
                Write-Host "  [!] Failed to disable $($user.Username): $_" -ForegroundColor Red
            }
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n══════════════ SUMMARY ══════════════" -ForegroundColor Cyan
Write-Host "  Total stale accounts : $count"
Write-Host "  Inactivity threshold : $DaysInactive days"
Write-Host "  Report saved to      : $ExportPath"
Write-Host "════════════════════════════════════`n" -ForegroundColor Cyan
