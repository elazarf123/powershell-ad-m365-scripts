<#
.SYNOPSIS
    Generates a Microsoft Intune device compliance report via Microsoft Graph.

.DESCRIPTION
    Connects to Microsoft Graph and exports a detailed compliance report for all
    managed devices enrolled in Microsoft Intune. Includes compliance state,
    OS/build details, last check-in, primary user, and ownership.

    Useful for:
      - Security reviews and access control audits
      - Evidence for SOC 2 / HIPAA / CIS endpoint compliance controls
      - Monthly endpoint health reporting
      - Pre-remediation baseline captures

    The script is fully read-only — no device settings are modified.

.PARAMETER ExportPath
    Full path for the output CSV report.
    Default: .\IntuneDeviceCompliance_<date>.csv

.PARAMETER ComplianceFilter
    Filter by compliance state. Accepted: All, Compliant, NonCompliant, Unknown, Error, InGracePeriod.
    Default: All

.PARAMETER PlatformFilter
    Filter by OS platform. Accepted: All, Windows, iOS, Android, macOS.
    Default: All

.PARAMETER LogPath
    Full path for the structured run log. Omit for console-only output.

.EXAMPLE
    .\Get-IntuneDeviceCompliance.ps1
    Exports full compliance report for all devices to the current directory.

.EXAMPLE
    .\Get-IntuneDeviceCompliance.ps1 -ComplianceFilter NonCompliant -ExportPath "C:\Reports\NonCompliant.csv"
    Exports only non-compliant devices for targeted remediation.

.EXAMPLE
    .\Get-IntuneDeviceCompliance.ps1 -PlatformFilter Windows -LogPath "C:\Logs\Intune.log"
    Exports Windows devices only with file logging enabled.

.NOTES
    Author:   Elazar Ferrer
    Version:  1.0
    Requires: Microsoft.Graph.DeviceManagement
    Scopes:   DeviceManagementManagedDevices.Read.All, User.Read.All

    SECURITY: This script is read-only. The above scopes are the minimum required.
    See SECURITY.md for authentication guidance and credential-free auth patterns.
#>

[CmdletBinding()]
param (
    [string]$ExportPath      = ".\IntuneDeviceCompliance_$(Get-Date -Format 'yyyy-MM-dd').csv",
    [ValidateSet("All","Compliant","NonCompliant","Unknown","Error","InGracePeriod")]
    [string]$ComplianceFilter = "All",
    [ValidateSet("All","Windows","iOS","Android","macOS")]
    [string]$PlatformFilter  = "All",
    [string]$LogPath         = ""
)

#Requires -Modules Microsoft.Graph.DeviceManagement

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

if ($LogPath) { Initialize-Log -LogPath $LogPath -ScriptName "Get-IntuneDeviceCompliance" }

Write-LogBanner -Title "Intune Device Compliance Report"

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Log "Connecting to Microsoft Graph..." -Level INFO

try {
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","User.Read.All" -NoWelcome
    Write-Log "Connected to Microsoft Graph" -Level SUCCESS
} catch {
    Write-Log "Failed to connect: $_" -Level ERROR
    exit 1
}

# ── Fetch managed devices ─────────────────────────────────────────────────────
Write-Log "Retrieving managed devices from Intune..." -Level INFO

try {
    $allDevices = Get-MgDeviceManagementManagedDevice -All -Property @(
        "Id","DeviceName","OperatingSystem","OsVersion","ComplianceState",
        "LastSyncDateTime","EnrolledDateTime","ManagementAgent","DeviceType",
        "ManagedDeviceOwnerType","UserDisplayName","UserPrincipalName",
        "Manufacturer","Model","SerialNumber","AzureADDeviceId",
        "IsEncrypted","JailBroken","WiFiMacAddress","EmailAddress"
    )
} catch {
    Write-Log "Failed to retrieve devices: $_" -Level ERROR
    Disconnect-MgGraph | Out-Null
    exit 1
}

Write-Log "Retrieved $($allDevices.Count) managed device(s)" -Level INFO

# ── Apply filters ─────────────────────────────────────────────────────────────
$filtered = $allDevices

if ($ComplianceFilter -ne "All") {
    $filtered = $filtered | Where-Object ComplianceState -eq $ComplianceFilter
    Write-Log "Compliance filter applied ($ComplianceFilter): $($filtered.Count) device(s) remaining" -Level INFO
}

if ($PlatformFilter -ne "All") {
    $filtered = $filtered | Where-Object OperatingSystem -like "*$PlatformFilter*"
    Write-Log "Platform filter applied ($PlatformFilter): $($filtered.Count) device(s) remaining" -Level INFO
}

Write-Log "Processing $($filtered.Count) device(s) after filters..." -Level INFO

# ── Build report ──────────────────────────────────────────────────────────────
$report = foreach ($device in $filtered) {

    $lastSync   = $device.LastSyncDateTime
    $daysSince  = if ($lastSync -and $lastSync -gt [datetime]::MinValue) {
        [math]::Round(((Get-Date) - [datetime]$lastSync).TotalDays)
    } else { "Never" }

    $isStale    = if ($daysSince -is [int]) { $daysSince -gt 30 } else { $true }

    [PSCustomObject]@{
        DeviceName          = $device.DeviceName
        PrimaryUser         = $device.UserDisplayName
        PrimaryUPN          = $device.UserPrincipalName
        ComplianceState     = $device.ComplianceState
        OperatingSystem     = $device.OperatingSystem
        OsVersion           = $device.OsVersion
        DeviceType          = $device.DeviceType
        Manufacturer        = $device.Manufacturer
        Model               = $device.Model
        Ownership           = $device.ManagedDeviceOwnerType
        ManagementAgent     = $device.ManagementAgent
        LastCheckIn         = $lastSync
        DaysSinceCheckIn    = $daysSince
        StaleCheckIn        = $isStale
        EnrolledDateTime    = $device.EnrolledDateTime
        IsEncrypted         = $device.IsEncrypted
        JailBroken          = $device.JailBroken
        AzureADDeviceId     = $device.AzureADDeviceId
        SerialNumber        = $device.SerialNumber
    }
}

# ── Export CSV ────────────────────────────────────────────────────────────────
$report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-Log "Report exported: $ExportPath" -Level SUCCESS

# ── Compliance state breakdown ────────────────────────────────────────────────
$total         = ($report | Measure-Object).Count
$compliant     = ($report | Where-Object ComplianceState -eq "compliant"      | Measure-Object).Count
$nonCompliant  = ($report | Where-Object ComplianceState -eq "noncompliant"   | Measure-Object).Count
$unknown       = ($report | Where-Object ComplianceState -eq "unknown"        | Measure-Object).Count
$inGrace       = ($report | Where-Object ComplianceState -eq "inGracePeriod"  | Measure-Object).Count
$errored       = ($report | Where-Object ComplianceState -eq "error"          | Measure-Object).Count
$staleDevices  = ($report | Where-Object StaleCheckIn -eq $true               | Measure-Object).Count

# Surface non-compliant devices to console for immediate visibility
if ($nonCompliant -gt 0) {
    Write-Log "$nonCompliant non-compliant device(s) found:" -Level WARNING
    $report | Where-Object ComplianceState -eq "noncompliant" |
        Format-Table DeviceName, PrimaryUser, OperatingSystem, DaysSinceCheckIn -AutoSize |
        Out-String | Write-Host -ForegroundColor Yellow
}

Write-LogSummary -Data ([ordered]@{
    "Total devices (filtered)" = $total
    "Compliant"                = $compliant
    "Non-Compliant"            = $nonCompliant
    "In Grace Period"          = $inGrace
    "Unknown"                  = $unknown
    "Error"                    = $errored
    "Stale check-in (30+ days)" = $staleDevices
    "Compliance filter"        = $ComplianceFilter
    "Platform filter"          = $PlatformFilter
    "Report"                   = $ExportPath
})

Disconnect-MgGraph | Out-Null
Write-Log "Disconnected from Microsoft Graph" -Level SUCCESS
