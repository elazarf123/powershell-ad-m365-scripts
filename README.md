# EF_SYS | PowerShell AD & M365 Admin Scripts

> **Elazar Ferrer** — IT Systems & Identity Administrator
> Active Directory • Microsoft 365 • Azure AD • PowerShell Automation

Production-grade PowerShell scripts for enterprise AD and M365 administration. Built from hands-on experience managing identity systems in regulated environments (HIPAA, NIST CSF 2.0).

---

## Scripts

### 👤 [New-BulkADUsers.ps1](./New-BulkADUsers.ps1)
Reads a structured CSV file and bulk-provisions AD user accounts using `New-ADUser`. Places each user in the correct OU based on department, assigns a temporary password, enables the account, and exports a timestamped results log.

**Use case:** New hire onboarding, bulk imports, lab provisioning.

```powershell
# Basic run using default SampleUsers.csv
.\New-BulkADUsers.ps1

# Custom CSV and log path
.\New-BulkADUsers.ps1 -CSVPath "C:\Imports\NewHires.csv" -LogPath "C:\Logs\Results.csv"

# Preview mode — no accounts created
.\New-BulkADUsers.ps1 -WhatIf
```

**Input:** `SampleUsers.csv` (included) — columns: FirstName, LastName, Username, Department, OU, Email, Title
**Output:** `BulkADUsers_Log_<timestamp>.csv` with per-user status (Created / Skipped / Failed).

---

### 🔍 [Get-ADStaleUsers.ps1](./Get-ADStaleUsers.ps1)
Finds enabled AD accounts that haven't logged in within a configurable threshold (default: 90 days). Exports a CSV report and optionally disables accounts.

**Use case:** Routine access reviews, HIPAA/NIST compliance audits, attack surface reduction.

```powershell
# Basic run — find accounts inactive 90+ days
.\Get-ADStaleUsers.ps1

# Custom threshold + auto-disable (use -WhatIf first!)
.\Get-ADStaleUsers.ps1 -DaysInactive 60 -DisableAccounts -WhatIf
```

**Output:** `StaleUsers_<date>.csv` with username, department, last logon, days inactive, manager.

---

### 🗂️ [Get-ADGroupAudit.ps1](./Get-ADGroupAudit.ps1)
Enumerates AD security and distribution groups using `Get-ADGroupMember` and exports a full membership report. Enriches each member with enabled status, department, and last logon date. Supports nested group resolution.

**Use case:** Quarterly access reviews, privilege audits, compliance documentation.

```powershell
# Audit all groups in the domain
.\Get-ADGroupAudit.ps1

# Target specific groups and resolve nested members
.\Get-ADGroupAudit.ps1 -GroupFilter "IT-*" -IncludeNestedMembers

# Scope to a specific OU
.\Get-ADGroupAudit.ps1 -SearchBase "OU=Groups,DC=corp,DC=local" -OutputPath "C:\Reports\Audit.csv"
```

**Output:** `ADGroupAudit_<timestamp>.csv` with group name, category, scope, member details, enabled status, and last logon.

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

**Requires:** `Install-Module Microsoft.Graph`

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
|--------|----------------|-------------|
| New-BulkADUsers.ps1 | ActiveDirectory | Domain Admin or delegated account creation |
| Get-ADStaleUsers.ps1 | ActiveDirectory | Domain read / Account Operator |
| Get-ADGroupAudit.ps1 | ActiveDirectory | Domain read |
| Get-M365LicenseReport.ps1 | Microsoft.Graph | User.Read.All, Org.Read.All |
| Backup-AllGPOs.ps1 | GroupPolicy | GPO Backup rights / Domain Admin |

**Environment:** Windows Server 2019 / 2022 • PowerShell 5.1+ • RSAT Tools

---

## About

Built and maintained by **Elazar Ferrer** — IT Systems & Identity Administrator with 3+ years managing enterprise AD, M365, and Azure AD environments in healthcare-regulated settings.

🌐 Portfolio: [elazarf123.github.io/cyber-port](https://elazarf123.github.io/cyber-port)
💼 LinkedIn: [linkedin.com/in/elazarf](https://linkedin.com/in/elazarf)
