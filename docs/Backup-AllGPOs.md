# Backup-AllGPOs.ps1

> **Category:** Active Directory | Group Policy Management  
> **Module:** `GroupPolicy` (RSAT)  
> **Minimum Rights:** GPO Backup rights / Domain Admin

---

## What Problem Does This Solve?

Group Policy Objects are critical infrastructure — they control security settings, software deployment, and desktop configurations across the entire domain. A single misconfigured or accidentally deleted GPO can affect hundreds or thousands of users and machines.

Before any change window involving GPOs, a full backup is mandatory for:

- **Safe change management** — restore to a known-good state if a change causes issues
- **Compliance evidence** — many frameworks require documented pre-change baselines
- **Disaster recovery** — restore individual or all GPOs after AD incidents
- **Change auditing** — compare backups over time to detect unexpected modifications

This script automates a full domain GPO backup, generates an HTML summary report, and supports ZIP archiving and automatic retention management.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 5.1 or 7+ |
| Module | `GroupPolicy` RSAT module |
| Rights | Domain Admin or delegated GPO backup permission |
| Storage | Sufficient disk space in `BackupRoot` for retained backups |

### Install RSAT (if needed)
```powershell
# Windows Server
Add-WindowsFeature GPMC

# Windows 10/11 client
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0
```

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `BackupRoot` | `string` | `C:\GPO_Backups` | Root folder where timestamped backup folders are created |
| `CreateZip` | `switch` | — | Compress the backup folder into a ZIP archive after export |
| `MaxBackups` | `int` | `30` | Number of timestamped backup folders to retain; older ones are pruned |

---

## Usage Examples

```powershell
# Default run — backs up all GPOs to C:\GPO_Backups\<timestamp>
.\Backup-AllGPOs.ps1

# Custom backup root with ZIP compression and 14-backup retention
.\Backup-AllGPOs.ps1 -BackupRoot "D:\Backups\GPO" -CreateZip -MaxBackups 14

# Back up to a network share (pre-change window)
.\Backup-AllGPOs.ps1 -BackupRoot "\\FileServer\GPOBackups" -CreateZip
```

---

## Output

Each run creates a timestamped subfolder under `BackupRoot` containing:

| Item | Description |
|------|-------------|
| `<GPO-GUID>/` | Individual GPO backup folder (one per GPO) |
| `GPO_Backup_Report_<timestamp>.html` | Color-coded HTML summary of all backed-up GPOs |
| `backup.log` | Plain-text run log |
| `<timestamp>.zip` | (Optional) ZIP archive of the entire backup folder |

---

## Change Management Workflow

### Pre-change (required)
```powershell
# 1. Run a full backup immediately before the change window
.\Backup-AllGPOs.ps1 -BackupRoot "\\FileServer\ChangeBackups" -CreateZip

# 2. Note the backup folder timestamp in your change record
```

### If rollback is needed
```powershell
# Restore a single GPO by GUID from the backup folder
Restore-GPO -BackupId "<GPO-GUID>" -Path "\\FileServer\ChangeBackups\<timestamp>"

# Restore ALL GPOs from a backup
Get-GPO -All | Restore-GPO -Path "\\FileServer\ChangeBackups\<timestamp>"
```

### Monthly scheduled backup (via Task Scheduler)
```powershell
# Schedule as a Basic Task running monthly under a service account
# Action: powershell.exe
# Arguments: -NonInteractive -File "C:\Scripts\Backup-AllGPOs.ps1" -BackupRoot "D:\Backups\GPO" -CreateZip -MaxBackups 12
```

---

## Retention Management

When `MaxBackups` is set, the script automatically deletes the oldest timestamped backup folders (and their ZIP files, if present) keeping only the most recent `MaxBackups` runs. This prevents unbounded disk growth for scheduled backups.

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `GroupPolicy module not found` | RSAT GPMC not installed | Install RSAT (see Prerequisites above) |
| `Access denied` creating backup folder | Insufficient rights on `BackupRoot` | Run as Domain Admin or grant write access to the backup share |
| Some GPOs show `Failed` status | GPO is corrupted or inaccessible | Check the specific GPO in GPMC; may need manual remediation |
| ZIP creation fails | Insufficient disk space or .NET issue | Verify free space; omit `-CreateZip` and archive manually |
| `Get-ADDomain` error | AD module not loaded | Install RSAT AD tools alongside GPMC |
