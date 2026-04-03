# EF_SYS | PowerShell AD & M365 Admin Scripts

> **Elazar Ferrer** — IT Systems & Identity Administrator  
> Active Directory • Microsoft 365 • Entra ID • Intune • PowerShell Automation

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue?logo=powershell)
![Graph SDK](https://img.shields.io/badge/Microsoft.Graph-SDK-0078d4?logo=microsoft)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)

Production-grade PowerShell scripts for enterprise AD and M365 administration. Built from hands-on experience managing identity, endpoint, and access systems in regulated environments (HIPAA, NIST CSF 2.0, SOC 2).

📄 **[View the full runbook docs index →](./docs/README.md)**

---

## 🎯 What Problems Do These Scripts Solve?

| Problem | Script | Time Saved |
|---------|--------|-----------|
| Bulk-provision 50+ new hires manually | `New-BulkADUsers.ps1` | 2+ hours → **< 5 min** |
| Find dormant AD accounts before an audit | `Get-ADStaleUsers.ps1` | Hours of manual review → **automated** |
| Produce quarterly group-membership evidence | `Get-ADGroupAudit.ps1` | Day-long task → **minutes** |
| Identify wasted M365 license spend | `Get-LicenseOptimizationReport.ps1` | Unknown waste → **itemized** |
| Clean up lingering B2B guest accounts | `Get-StaleGuestReport.ps1` | Blind spots → **quantified + actionable** |
| Document Conditional Access before changes | `Export-ConditionalAccessPolicies.ps1` | Manual screenshots → **automated CSV/JSON** |
| Identify non-compliant Intune devices | `Get-IntuneDeviceCompliance.ps1` | Manual portal review → **filterable report** |
| Back up all GPOs before a change window | `Backup-AllGPOs.ps1` | Manual export → **one command** |

---

## 🗂️ Repository Structure

```
powershell-ad-m365-scripts/
├── src/
│   ├── graph/                        # Microsoft Graph-based scripts (M365 / Entra / Intune)
│   │   ├── Get-LicenseOptimizationReport.ps1
│   │   ├── Get-StaleGuestReport.ps1
│   │   ├── Export-ConditionalAccessPolicies.ps1
│   │   └── Get-IntuneDeviceCompliance.ps1
│   └── helpers/
│       └── Write-Log.ps1             # Shared logging module (imported by all src/ scripts)
├── tests/
│   └── Write-Log.Tests.ps1           # Pester 5 unit tests for logging helper
├── docs/                             # Runbook documentation for all major scripts
│   ├── README.md                     # Master docs index & portfolio landing page
│   ├── Get-LicenseOptimizationReport.md
│   ├── Get-StaleGuestReport.md
│   ├── Export-ConditionalAccessPolicies.md
│   ├── Get-IntuneDeviceCompliance.md
│   ├── New-BulkADUsers.md
│   ├── Get-ADStaleUsers.md
│   └── Get-ADGroupAudit.md
├── examples/                         # Sanitized sample CSV outputs (no real tenant data)
│   ├── LicenseOptimization_Users_sample.csv
│   ├── LicenseOptimization_SKUs_sample.csv
│   ├── StaleGuests_sample.csv
│   ├── ConditionalAccessPolicies_sample.csv
│   └── IntuneDeviceCompliance_sample.csv
│
│── New-BulkADUsers.ps1               # AD: Bulk user provisioning from CSV
│── Get-ADStaleUsers.ps1              # AD: Stale account detection + optional disable
│── Get-ADGroupAudit.ps1              # AD: Group membership audit with nested resolution
│── Get-M365LicenseReport.ps1         # Graph: M365 license assignment report
│── Backup-AllGPOs.ps1                # GPO: Full domain backup with HTML report
│── SampleUsers.csv                   # Sample input for New-BulkADUsers.ps1
│
├── .gitignore
├── SECURITY.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

---

## 🔧 Prerequisites & Installation

### Step 1 — PowerShell Version

```powershell
$PSVersionTable.PSVersion   # Check your version
```

- **Minimum:** PowerShell 5.1 (Windows PowerShell — for AD and GPO scripts)
- **Recommended:** PowerShell 7.4+ (for `src/graph/` scripts — better null-safety, performance)

### Step 2 — Install Required Modules

```powershell
# Microsoft Graph SDK (required for all src/graph/ scripts)
Install-Module Microsoft.Graph -Scope CurrentUser

# Active Directory module — install RSAT on Windows Server / Windows 10+
# Server: Add-WindowsFeature RSAT-AD-PowerShell
# Client: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Verify
Get-Module Microsoft.Graph -ListAvailable | Select-Object Name, Version
```

### Step 3 — Clone or Download

```powershell
git clone https://github.com/elazarf123/powershell-ad-m365-scripts.git
cd powershell-ad-m365-scripts
```

---

## 🔐 Authentication Options

All `src/graph/` scripts connect to Microsoft Graph. **No credentials are ever stored in code.**  
See [SECURITY.md](./SECURITY.md) for the full policy.

### Option A — Interactive (developer / one-off runs)

```powershell
# Each script calls Connect-MgGraph automatically.
# A browser sign-in window opens; consent is cached for the session.
.\src\graph\Get-LicenseOptimizationReport.ps1
```

### Option B — Certificate-Based App Registration (automation / scheduled tasks)

```powershell
# 1. Create an App Registration in Entra ID and upload a certificate.
# 2. Grant the app the permissions listed below (no user sign-in needed).
# 3. Store IDs in environment variables — NOT in the script file.

$env:TENANT_ID       = "<your-tenant-guid>"
$env:APP_CLIENT_ID   = "<app-registration-client-id>"
$env:CERT_THUMBPRINT = "<thumbprint-from-cert-store>"

Connect-MgGraph -ClientId $env:APP_CLIENT_ID `
                -TenantId $env:TENANT_ID `
                -CertificateThumbprint $env:CERT_THUMBPRINT -NoWelcome

.\src\graph\Get-IntuneDeviceCompliance.ps1
```

### Option C — Managed Identity (Azure-hosted workloads)

```powershell
Connect-MgGraph -Identity   # Uses the VM/Function App's system-assigned managed identity
```

---

## 📜 Scripts

### 🆕 Microsoft Graph Scripts (`src/graph/`)

---

#### 📊 [Get-LicenseOptimizationReport.ps1](./src/graph/Get-LicenseOptimizationReport.ps1)
Identifies M365 license waste: inactive licensed users, high-cost SKU assignments for low-activity accounts, and over-provisioned SKUs. Exports per-user and org-level SKU CSV reports.

**Use case:** Monthly license reviews, finance reporting, offboarding hygiene.

```powershell
# Default run
.\src\graph\Get-LicenseOptimizationReport.ps1

# 60-day inactivity threshold, custom output folder
.\src\graph\Get-LicenseOptimizationReport.ps1 -InactiveDays 60 -ExportPath "C:\Reports"
```

**Required scopes:** `User.Read.All`, `Organization.Read.All`, `AuditLog.Read.All`  
**Sample output:** [examples/LicenseOptimization_Users_sample.csv](./examples/LicenseOptimization_Users_sample.csv)  
**Full docs:** [docs/Get-LicenseOptimizationReport.md](./docs/Get-LicenseOptimizationReport.md)

---

#### 👥 [Get-StaleGuestReport.ps1](./src/graph/Get-StaleGuestReport.ps1)
Finds B2B guest accounts that haven't signed in for a configurable period (default: 90 days). Supports safe disable and remove actions with `-WhatIf` / `-Confirm`.

**Use case:** Quarterly external access reviews, HIPAA/NIST identity hygiene, attack surface reduction.

```powershell
# Report only — no changes
.\src\graph\Get-StaleGuestReport.ps1

# Preview which accounts would be disabled
.\src\graph\Get-StaleGuestReport.ps1 -DisableGuests -WhatIf

# Disable with per-account confirmation
.\src\graph\Get-StaleGuestReport.ps1 -DisableGuests -Confirm
```

**Required scopes:** `User.Read.All`, `AuditLog.Read.All` (+ `User.ReadWrite.All` for write actions)  
**Sample output:** [examples/StaleGuests_sample.csv](./examples/StaleGuests_sample.csv)  
**Full docs:** [docs/Get-StaleGuestReport.md](./docs/Get-StaleGuestReport.md)

---

#### 🛡️ [Export-ConditionalAccessPolicies.ps1](./src/graph/Export-ConditionalAccessPolicies.ps1)
Read-only export of all Conditional Access policies — state, user/group/app assignments, grant controls (MFA, compliant device, block), and session controls. Optional full-fidelity JSON archive.

**Use case:** Pre-change baselines, post-change validation, SOC 2 / ISO 27001 compliance evidence.

```powershell
# Export to CSV
.\src\graph\Export-ConditionalAccessPolicies.ps1

# Export CSV + JSON archive
.\src\graph\Export-ConditionalAccessPolicies.ps1 -ExportPath "C:\Reports\CA.csv" -ExportJson
```

**Required scopes:** `Policy.Read.All`  
**Sample output:** [examples/ConditionalAccessPolicies_sample.csv](./examples/ConditionalAccessPolicies_sample.csv)  
**Full docs:** [docs/Export-ConditionalAccessPolicies.md](./docs/Export-ConditionalAccessPolicies.md)

---

#### 📱 [Get-IntuneDeviceCompliance.ps1](./src/graph/Get-IntuneDeviceCompliance.ps1)
Reports device compliance state, last check-in, OS version, encryption status, and jailbreak detection for all Intune-managed devices. Filterable by compliance state and OS platform.

**Use case:** Security reviews, endpoint posture reporting, stale device identification, CIS/NIST endpoint controls evidence.

```powershell
# Full report
.\src\graph\Get-IntuneDeviceCompliance.ps1

# Non-compliant Windows devices only
.\src\graph\Get-IntuneDeviceCompliance.ps1 -ComplianceFilter NonCompliant -PlatformFilter Windows
```

**Required scopes:** `DeviceManagementManagedDevices.Read.All`, `User.Read.All`  
**Sample output:** [examples/IntuneDeviceCompliance_sample.csv](./examples/IntuneDeviceCompliance_sample.csv)  
**Full docs:** [docs/Get-IntuneDeviceCompliance.md](./docs/Get-IntuneDeviceCompliance.md)

---

### 🖥️ Active Directory Scripts (root)

---

#### 👤 [New-BulkADUsers.ps1](./New-BulkADUsers.ps1)
Bulk-provisions AD user accounts from a CSV. Places each user in the correct OU, sets a temporary password, enforces change-at-first-logon, and exports a timestamped results log.

```powershell
.\New-BulkADUsers.ps1                                    # Uses default SampleUsers.csv
.\New-BulkADUsers.ps1 -CSVPath "C:\Imports\NewHires.csv" # Custom CSV
.\New-BulkADUsers.ps1 -WhatIf                            # Preview only
```

**Input:** `SampleUsers.csv` | **Output:** `BulkADUsers_Log_<timestamp>.csv`  
**Full docs:** [docs/New-BulkADUsers.md](./docs/New-BulkADUsers.md)

---

#### 🔍 [Get-ADStaleUsers.ps1](./Get-ADStaleUsers.ps1)
Finds enabled AD accounts inactive beyond a threshold (default: 90 days). Exports a CSV and optionally disables accounts with `-WhatIf` support.

```powershell
.\Get-ADStaleUsers.ps1
.\Get-ADStaleUsers.ps1 -DaysInactive 60 -DisableAccounts -WhatIf
```

**Output:** `StaleUsers_<date>.csv`  
**Full docs:** [docs/Get-ADStaleUsers.md](./docs/Get-ADStaleUsers.md)

---

#### 🗂️ [Get-ADGroupAudit.ps1](./Get-ADGroupAudit.ps1)
Enumerates all AD groups and exports enriched membership reports (enabled status, department, last logon). Supports nested group resolution and OU scoping.

```powershell
.\Get-ADGroupAudit.ps1
.\Get-ADGroupAudit.ps1 -GroupFilter "IT-*" -IncludeNestedMembers
```

**Output:** `ADGroupAudit_<timestamp>.csv`  
**Full docs:** [docs/Get-ADGroupAudit.md](./docs/Get-ADGroupAudit.md)

---

#### 📋 [Get-M365LicenseReport.ps1](./Get-M365LicenseReport.ps1)
Connects to Microsoft Graph and exports a per-user license assignment report with SKU-to-friendly-name mapping, available seats, and last sign-in.

```powershell
.\Get-M365LicenseReport.ps1
.\Get-M365LicenseReport.ps1 -ShowUnlicensed -ExportPath "C:\Reports\Licenses.csv"
```

---

#### 💾 [Backup-AllGPOs.ps1](./Backup-AllGPOs.ps1)
Backs up every domain GPO to timestamped folders, generates an HTML report, supports ZIP compression and retention pruning.

```powershell
.\Backup-AllGPOs.ps1
.\Backup-AllGPOs.ps1 -BackupRoot "D:\Backups\GPO" -CreateZip -MaxBackups 14
```

---

## 📋 Requirements & Permissions

| Script | Module(s) Required | Minimum Graph Scopes / AD Rights |
|--------|--------------------|----------------------------------|
| `New-BulkADUsers.ps1` | `ActiveDirectory` | Domain Admin or delegated account creation |
| `Get-ADStaleUsers.ps1` | `ActiveDirectory` | Domain read / Account Operator |
| `Get-ADGroupAudit.ps1` | `ActiveDirectory` | Domain read |
| `Get-M365LicenseReport.ps1` | `Microsoft.Graph` | `User.Read.All`, `Organization.Read.All` |
| `Backup-AllGPOs.ps1` | `GroupPolicy` | GPO Backup rights / Domain Admin |
| `Get-LicenseOptimizationReport.ps1` | `Microsoft.Graph` | `User.Read.All`, `Organization.Read.All`, `AuditLog.Read.All` |
| `Get-StaleGuestReport.ps1` | `Microsoft.Graph` | `User.Read.All`, `AuditLog.Read.All` (+ `User.ReadWrite.All` for write actions) |
| `Export-ConditionalAccessPolicies.ps1` | `Microsoft.Graph` | `Policy.Read.All` |
| `Get-IntuneDeviceCompliance.ps1` | `Microsoft.Graph` | `DeviceManagementManagedDevices.Read.All`, `User.Read.All` |

**Principle of Least Privilege:** Always grant only the scopes your run requires. For report-only runs, read scopes are sufficient. See [SECURITY.md](./SECURITY.md) for app registration guidance.

---

## 🧪 Running the Tests

```powershell
# Install Pester 5 (once)
Install-Module Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester .\tests\ -Output Detailed

# Run a single test file
Invoke-Pester .\tests\Write-Log.Tests.ps1 -Output Detailed
```

---

## 🔒 Security & Best Practices

> ⚠️ These scripts interact with critical identity and endpoint infrastructure. Read [SECURITY.md](./SECURITY.md) before running in production.

- **No secrets in code** — credentials, tokens, and tenant IDs must never be committed (`.gitignore` blocks common secret file types)
- **Test before production** — run with `-WhatIf` (where supported) in a lab or staging environment first
- **Least-privilege** — use dedicated service accounts or app registrations scoped to the permissions each script needs
- **Audit all executions** — keep the timestamped logs generated by each script in a secured, access-controlled location
- **Secure Graph auth** — prefer certificate-based or managed-identity authentication for unattended runs over interactive sign-in
- **Review CSV inputs** — validate bulk-operation inputs before running to prevent unintended account creation or deletion

---

## About

Built and maintained by **Elazar Ferrer** — IT Systems & Identity Administrator with experience managing enterprise AD, M365, Entra ID, and Intune environments in healthcare-regulated settings.

🌐 Portfolio: [elazarf123.github.io/cyber-port](https://elazarf123.github.io/cyber-port)  
💼 LinkedIn: [linkedin.com/in/elazarf](https://linkedin.com/in/elazarf)

---

*See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines · [CHANGELOG.md](./CHANGELOG.md) for version history · [SECURITY.md](./SECURITY.md) for security policy · [LICENSE](./LICENSE) for terms of use*
