# EF_SYS | PowerShell AD & M365 Admin Scripts

> **Elazar Ferrer** — IT Systems & Identity Administrator | Active DoD Secret Clearance  
> Active Directory • Microsoft 365 • Azure AD • PowerShell Automation

Production-grade PowerShell scripts for enterprise AD and M365 administration. Built from hands-on experience managing identity systems in regulated environments (HIPAA, DoD).

---

## Scripts

### 🔍 [Get-ADStaleUsers.ps1](./Get-ADStaleUsers.ps1)
Finds enabled AD accounts that haven't logged in within a configurable threshold (default: 90 days). Exports a CSV report and optionally disables accounts.

**Use case:** Routine access reviews, HIPAA/NIST compliance audits, attack surface reduction.

```powershell
# Basic run — find accounts inactive 90+ days
.\Get-ADStaleUsers.ps1

# Custom threshold + auto-disable (use -WhatIf first!)
.\Get-ADStaleUsers.ps1 -DaysInactive 60 -DisableAccounts -WhatIf
```

**Output:** `StaleUsers_2025-01-15.csv` with username, department, last logon, days inactive, manager.

---

### 📋 [Get-M365LicenseReport.ps1](./Get-M365LicenseReport.ps1)
Connects to Microsoft Graph and exports a full M365 license assignment report — who has what license, last sign-in, department, and available seats per SKU.

**Use case:** License cost optimization, offboarding audits, compliance documentation.

```powershell
# Export licensed users to CSV
.\Get-M365LicenseReport.ps1

# Include unlicensed users
.\Get-M365LicenseReport.ps1 -ShowUnlicensed -ExportPath "C:\Reports\Licenses.csv"
```

**Requires:** `Microsoft.Graph` PowerShell SDK — `Install-Module Microsoft.Graph`

---

### 💾 [Backup-AllGPOs.ps1](./Backup-AllGPOs.ps1)
Backs up every GPO in the domain to timestamped folders, generates an HTML report with status, linked OUs, and modification dates. Supports ZIP compression and auto-pruning of old backups.

**Use case:** Pre-change documentation, disaster recovery, change management compliance.

```powershell
# Full backup with defaults
.\Backup-AllGPOs.ps1

# Custom path, ZIP archive, keep 14 days of backups
.\Backup-AllGPOs.ps1 -BackupRoot "D:\Backups\GPO" -CreateZip -MaxBackups 14
```

**Output:** Timestamped folder + HTML report with color-coded status per GPO.

---

## Requirements

| Script | Module Required | Permissions |
|---|---|---|
| Get-ADStaleUsers.ps1 | `ActiveDirectory` | Domain read / Account Operator |
| Get-M365LicenseReport.ps1 | `Microsoft.Graph` | User.Read.All, Org.Read.All |
| Backup-AllGPOs.ps1 | `GroupPolicy` | GPO Backup rights / Domain Admin |

---

## Environment

- Windows Server 2019 / 2022
- PowerShell 5.1+
- RSAT Tools (for AD and GPO modules)

---

## About

Built and maintained by **Elazar Ferrer** — IT Systems & Identity Administrator with 3+ years managing enterprise AD, M365, and Azure AD environments.

- 🌐 Portfolio: [elazarf123.github.io/cyber-port](https://elazarf123.github.io/cyber-port)
- 💼 LinkedIn: [linkedin.com/in/elazarf](https://linkedin.com/in/elazarf)
- 🔐 Active DoD Secret Clearance
