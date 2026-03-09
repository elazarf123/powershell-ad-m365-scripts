<#
.SYNOPSIS
    Backs up all Group Policy Objects in the domain to a timestamped folder.

.DESCRIPTION
    Exports every GPO in the domain to individual subfolders with full metadata,
    generates an HTML report, and optionally creates a ZIP archive for storage.
    Designed for change management compliance in DoD/HIPAA/NIST environments
    where GPO configuration must be documented before any changes.

.PARAMETER BackupRoot
    Root folder for all GPO backups. Default: C:\GPO_Backups

.PARAMETER CreateZip
    Compress the backup folder into a ZIP archive after export.

.PARAMETER MaxBackups
    Number of dated backup folders to retain. Older ones are pruned. Default: 30.

.EXAMPLE
    .\Backup-AllGPOs.ps1
    Backs up all GPOs to C:\GPO_Backups\<timestamp>

.EXAMPLE
    .\Backup-AllGPOs.ps1 -BackupRoot "D:\Backups\GPO" -CreateZip -MaxBackups 14
    Backs up to custom path, creates ZIP, keeps 14 most recent backups.

.NOTES
    Author:  Elazar Ferrer
    Version: 1.0
    Requires: GroupPolicy module, Domain Admin or GPO read/backup rights
#>

[CmdletBinding()]
param (
    [string]$BackupRoot  = "C:\GPO_Backups",
    [switch]$CreateZip,
    [int]$MaxBackups     = 30
)

#Requires -Modules GroupPolicy

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         GPO Full Domain Backup           ║" -ForegroundColor Cyan
Write-Host "║          Elazar Ferrer | EF_SYS          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ── Setup Paths ───────────────────────────────────────────────────────────────
$timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath  = Join-Path $BackupRoot $timestamp
$reportPath  = Join-Path $backupPath "GPO_Backup_Report_$timestamp.html"
$logPath     = Join-Path $backupPath "backup.log"
$domainName  = (Get-ADDomain).DNSRoot

Write-Host "[*] Domain      : $domainName" -ForegroundColor Yellow
Write-Host "[*] Backup Path : $backupPath" -ForegroundColor Yellow
Write-Host "[*] Timestamp   : $timestamp`n" -ForegroundColor Yellow

# ── Create Directory ──────────────────────────────────────────────────────────
try {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Write-Host "[+] Created backup directory." -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to create directory: $_" -ForegroundColor Red
    exit 1
}

# ── Get All GPOs ──────────────────────────────────────────────────────────────
Write-Host "[*] Retrieving all GPOs from domain..." -ForegroundColor Yellow
$allGPOs = Get-GPO -All -Domain $domainName
$totalGPOs = ($allGPOs | Measure-Object).Count
Write-Host "[+] Found $totalGPOs GPO(s) to back up.`n" -ForegroundColor Green

# ── Backup Loop ───────────────────────────────────────────────────────────────
$results     = @()
$successCount = 0
$failCount    = 0

foreach ($gpo in $allGPOs) {

    $safeName   = $gpo.DisplayName -replace '[\\/:*?"<>|]', '_'
    $gpoFolder  = Join-Path $backupPath $safeName

    Write-Host "  [*] Backing up: $($gpo.DisplayName)" -NoNewline

    try {
        $backup = Backup-GPO -Guid $gpo.Id -Path $gpoFolder -Domain $domainName
        $successCount++
        Write-Host " ✓" -ForegroundColor Green

        $results += [PSCustomObject]@{
            GPOName          = $gpo.DisplayName
            GUID             = $gpo.Id
            Status           = "Success"
            BackupID         = $backup.Id
            ModifiedDate     = $gpo.ModificationTime
            ComputerSettings = $gpo.Computer.Enabled
            UserSettings     = $gpo.User.Enabled
            LinkedTo         = ($gpo.Links | ForEach-Object { $_.Target }) -join "; "
            BackupFolder     = $gpoFolder
        }

    } catch {
        $failCount++
        Write-Host " ✗ FAILED" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red

        $results += [PSCustomObject]@{
            GPOName          = $gpo.DisplayName
            GUID             = $gpo.Id
            Status           = "FAILED: $_"
            BackupID         = "N/A"
            ModifiedDate     = $gpo.ModificationTime
            ComputerSettings = $gpo.Computer.Enabled
            UserSettings     = $gpo.User.Enabled
            LinkedTo         = "N/A"
            BackupFolder     = "N/A"
        }
    }
}

# ── HTML Report ───────────────────────────────────────────────────────────────
Write-Host "`n[*] Generating HTML report..." -ForegroundColor Yellow

$tableRows = $results | ForEach-Object {
    $rowColor = if ($_.Status -eq "Success") { "#1a3a1a" } else { "#3a1a1a" }
    $statusColor = if ($_.Status -eq "Success") { "#00ff88" } else { "#ff4444" }
    @"
    <tr style="background:$rowColor">
        <td>$($_.GPOName)</td>
        <td style="font-size:0.8em;color:#888">$($_.GUID)</td>
        <td style="color:$statusColor;font-weight:bold">$($_.Status)</td>
        <td>$($_.ModifiedDate)</td>
        <td>$($_.ComputerSettings)</td>
        <td>$($_.UserSettings)</td>
        <td style="font-size:0.85em">$($_.LinkedTo)</td>
    </tr>
"@
}

$html = @"
<!DOCTYPE html>
<html>
<head>
<title>GPO Backup Report - $timestamp</title>
<style>
  body { background:#0d0d0d; color:#c0c0c0; font-family:'Courier New',monospace; padding:30px; }
  h1 { color:#00e5ff; border-bottom:1px solid #00e5ff; padding-bottom:10px; }
  .meta { color:#888; margin-bottom:20px; }
  .summary { display:flex; gap:30px; margin-bottom:25px; }
  .stat { background:#111; border:1px solid #00e5ff; padding:15px 25px; border-radius:4px; text-align:center; }
  .stat .num { font-size:2em; color:#00e5ff; font-weight:bold; }
  .stat .lbl { color:#888; font-size:0.85em; }
  table { width:100%; border-collapse:collapse; font-size:0.9em; }
  th { background:#001a2a; color:#00e5ff; padding:10px; text-align:left; border:1px solid #1a3a4a; }
  td { padding:8px 10px; border:1px solid #1a2a1a; vertical-align:top; }
  .footer { margin-top:30px; color:#555; font-size:0.8em; }
</style>
</head>
<body>
<h1>⚙ GPO Backup Report</h1>
<div class="meta">
  Domain: $domainName &nbsp;|&nbsp; Backup Time: $timestamp &nbsp;|&nbsp; Generated by: EF_SYS
</div>
<div class="summary">
  <div class="stat"><div class="num">$totalGPOs</div><div class="lbl">Total GPOs</div></div>
  <div class="stat"><div class="num" style="color:#00ff88">$successCount</div><div class="lbl">Successful</div></div>
  <div class="stat"><div class="num" style="color:#ff4444">$failCount</div><div class="lbl">Failed</div></div>
</div>
<table>
  <tr><th>GPO Name</th><th>GUID</th><th>Status</th><th>Last Modified</th><th>Computer</th><th>User</th><th>Linked To</th></tr>
  $($tableRows -join "`n")
</table>
<div class="footer">Backup Path: $backupPath</div>
</body>
</html>
"@

$html | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "[+] HTML report saved: $reportPath" -ForegroundColor Green

# ── Optional ZIP ──────────────────────────────────────────────────────────────
if ($CreateZip) {
    $zipPath = "$backupPath.zip"
    Write-Host "[*] Creating ZIP archive..." -ForegroundColor Yellow
    try {
        Compress-Archive -Path $backupPath -DestinationPath $zipPath -Force
        Write-Host "[+] ZIP created: $zipPath" -ForegroundColor Green
    } catch {
        Write-Host "[!] ZIP failed: $_" -ForegroundColor Red
    }
}

# ── Prune Old Backups ─────────────────────────────────────────────────────────
Write-Host "[*] Checking backup retention (keep $MaxBackups)..." -ForegroundColor Yellow
$existingBackups = Get-ChildItem -Path $BackupRoot -Directory | Sort-Object Name -Descending
if ($existingBackups.Count -gt $MaxBackups) {
    $toDelete = $existingBackups | Select-Object -Skip $MaxBackups
    foreach ($old in $toDelete) {
        Remove-Item -Path $old.FullName -Recurse -Force
        Write-Host "  [-] Removed old backup: $($old.Name)" -ForegroundColor DarkGray
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n══════════════ SUMMARY ══════════════" -ForegroundColor Cyan
Write-Host "  Total GPOs backed up : $successCount / $totalGPOs"
Write-Host "  Failed               : $failCount"
Write-Host "  Backup location      : $backupPath"
Write-Host "  HTML report          : $reportPath"
Write-Host "════════════════════════════════════`n" -ForegroundColor Cyan
