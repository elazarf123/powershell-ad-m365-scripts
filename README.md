# EF_SYS | PowerShell AD & M365 Admin Scripts

> **Elazar Ferrer** — IT Systems & Identity Administrator
> Active Directory • Microsoft 365 • Azure AD • PowerShell Automation

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)

Production-grade PowerShell scripts for enterprise AD and M365 administration. Built from hands-on experience managing identity systems in regulated environments (HIPAA, NIST CSF 2.0).

---

## 🎯 Problem This Solves

Managing Active Directory and Microsoft 365 at enterprise scale is time-consuming and error-prone when done manually. These scripts eliminate repetitive tasks and reduce human error in critical identity and access management workflows:

- Reduces bulk user provisioning from **2+ hours to under 5 minutes**
- Automates stale account detection to reduce **security exposure** from orphaned identities
- Generates compliance-ready audit reports for **HIPAA / NIST CSF 2.0 / SOC 2** reviews
- Optimizes M365 license spend through clear **cost visibility**
- Enables GPO **disaster recovery** with versioned, automated backups

---

## 🚀 Features

- [x] Bulk AD user provisioning from CSV with per-user OU placement and results logging
- [x] Stale account detection with configurable inactivity threshold and optional auto-disable
- [x] AD group membership auditing with nested group resolution and enriched user detail
- [x] Microsoft 365 license reporting via Microsoft Graph with SKU-to-friendly-name mapping
- [x] Full GPO domain backup with HTML report, ZIP compression, and retention pruning

---

## 🔧 Prerequisites

| Requirement | Details |
|-------------|---------|
| PowerShell  | 5.1 or higher |
| OS          | Windows Server 2019 / 2022 (with RSAT tools) |
| AD Scripts  | ActiveDirectory PowerShell module (`RSAT: Active Directory DS and LDS Tools`) |
| M365 Script | Microsoft Graph PowerShell SDK (`Install-Module Microsoft.Graph`) |
| GPO Script  | GroupPolicy module (included with RSAT Group Policy Management Tools) |
| Permissions | See per-script requirements in the table below |

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

## 🔒 Security & Best Practices

> ⚠️ These scripts interact with critical identity infrastructure. Follow these practices before and during use:

- **Test before production** — Run with `-WhatIf` (where supported) in a lab or staging environment first
- **Least-privilege accounts** — Use dedicated service accounts scoped to only the permissions each script requires; avoid running as Domain Admin where possible
- **Review CSV inputs** — Validate CSV data before running bulk provisioning to prevent unintended account creation
- **Audit all executions** — Keep the timestamped logs generated by each script; store them in a secured, access-controlled location
- **Protect the scripts** — Store this repository in a controlled location; restrict write access to prevent unauthorized modification
- **Rotate credentials** — Do not hardcode credentials; use the `-DefaultPassword` parameter to supply temporary passwords and enforce change-at-first-logon
- **Secure Graph connections** — Use app registrations with certificate-based auth for unattended `Get-M365LicenseReport.ps1` runs rather than delegated interactive login

---

## About

Built and maintained by **Elazar Ferrer** — IT Systems & Identity Administrator with 3+ years managing enterprise AD, M365, and Azure AD environments in healthcare-regulated settings.

🌐 Portfolio: [elazarf123.github.io/cyber-port](https://elazarf123.github.io/cyber-port)
💼 LinkedIn: [linkedin.com/in/elazarf](https://linkedin.com/in/elazarf)

---

*See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines · [CHANGELOG.md](./CHANGELOG.md) for version history · [LICENSE](./LICENSE) for terms of use*
