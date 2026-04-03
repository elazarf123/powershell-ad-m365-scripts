# EF_SYS — Microsoft 365 & Active Directory Automation Runbooks

> **Elazar Ferrer** | IT Systems & Identity Administrator  
> Active Directory · Microsoft 365 · Entra ID · Intune · PowerShell · Microsoft Graph

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue?logo=powershell)](https://github.com/elazarf123/powershell-ad-m365-scripts)
[![Graph SDK](https://img.shields.io/badge/Microsoft.Graph-SDK-0078d4?logo=microsoft)](https://github.com/elazarf123/powershell-ad-m365-scripts)
[![License](https://img.shields.io/badge/License-MIT-green)](../LICENSE)

---

## Why This Toolkit Exists

Enterprise IT teams in regulated environments (HIPAA, NIST CSF 2.0, SOC 2) spend significant time on repeatable tasks:  
license reviews, external-access audits, endpoint compliance checks, and change-control documentation.  
This toolkit automates those workflows with production-hardened PowerShell scripts — reducing multi-hour manual tasks  
to single commands while maintaining a full audit trail.

---

## At a Glance

| Automation Area | Script | Problem Solved | Time Saved |
|----------------|--------|---------------|-----------|
| 💰 License Waste | [Get-LicenseOptimizationReport](Get-LicenseOptimizationReport.md) | Identifies inactive licensed users and over-provisioned SKUs | Days → **minutes** |
| 🔐 Guest Hygiene | [Get-StaleGuestReport](Get-StaleGuestReport.md) | Finds and removes stale B2B guests with `-WhatIf` safety | Manual review → **automated** |
| 🛡️ CA Policy Audit | [Export-ConditionalAccessPolicies](Export-ConditionalAccessPolicies.md) | Exports all CA policies for compliance evidence & change baselines | Screenshots → **CSV/JSON** |
| 📱 Endpoint Compliance | [Get-IntuneDeviceCompliance](Get-IntuneDeviceCompliance.md) | Reports non-compliant, stale, and at-risk devices across all platforms | Portal review → **report** |
| 👤 Bulk Provisioning | [New-BulkADUsers](New-BulkADUsers.md) | Provisions 50+ AD users from CSV in minutes | 2+ hours → **< 5 min** |
| 🔍 Stale Accounts | [Get-ADStaleUsers](Get-ADStaleUsers.md) | Detects dormant AD accounts before audits | Hours manual → **automated** |
| 🗂️ Group Auditing | [Get-ADGroupAudit](Get-ADGroupAudit.md) | Produces quarterly access-review evidence | Day-long task → **minutes** |
| 💾 GPO Backup | [Backup-AllGPOs](../Backup-AllGPOs.ps1) | Full domain GPO backup before every change window | Manual → **one command** |

---

## Script Runbooks

### Microsoft Graph Scripts (`src/graph/`)

These scripts connect to Microsoft Graph using the [Microsoft.Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview).  
They support interactive, certificate-based, and Managed Identity authentication.  
**No credentials are ever stored in code** — see [SECURITY.md](../SECURITY.md).

| Script | Runbook | Scopes Required |
|--------|---------|----------------|
| `Get-LicenseOptimizationReport.ps1` | [📄 Runbook](Get-LicenseOptimizationReport.md) | `User.Read.All`, `Organization.Read.All`, `AuditLog.Read.All` |
| `Get-StaleGuestReport.ps1` | [📄 Runbook](Get-StaleGuestReport.md) | `User.Read.All`, `AuditLog.Read.All` (+ `User.ReadWrite.All` for write actions) |
| `Export-ConditionalAccessPolicies.ps1` | [📄 Runbook](Export-ConditionalAccessPolicies.md) | `Policy.Read.All` |
| `Get-IntuneDeviceCompliance.ps1` | [📄 Runbook](Get-IntuneDeviceCompliance.md) | `DeviceManagementManagedDevices.Read.All`, `User.Read.All` |

### Active Directory Scripts (root)

These scripts use the `ActiveDirectory` RSAT module and run against an on-premises or hybrid AD environment.

| Script | Runbook | AD Rights Required |
|--------|---------|-------------------|
| `New-BulkADUsers.ps1` | [📄 Runbook](New-BulkADUsers.md) | Domain Admin or delegated account-creation rights |
| `Get-ADStaleUsers.ps1` | [📄 Runbook](Get-ADStaleUsers.md) | Domain read / Account Operator |
| `Get-ADGroupAudit.ps1` | [📄 Runbook](Get-ADGroupAudit.md) | Domain read |
| `Backup-AllGPOs.ps1` | *(see script header)* | GPO Backup rights / Domain Admin |

---

## Security & Compliance Highlights

- **Zero credentials in code** — all auth patterns use environment variables, certificate stores, or Managed Identity
- **Principle of least privilege** — each script documents its minimum required scopes
- **-WhatIf / -Confirm** on every destructive operation — stale guest disable/remove never runs silently
- **Structured logging** — every run produces a timestamped log via the shared `Write-Log` helper
- **PII-safe samples** — all files in `examples/` use fictional data (`contoso.com`); no real tenant data in this repo
- **Compliance-aligned** — built for HIPAA, NIST CSF 2.0, and SOC 2 environments

Full details: [SECURITY.md](../SECURITY.md)

---

## Quick Start

```powershell
# 1. Install the Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Scope CurrentUser

# 2. Clone the repository
git clone https://github.com/elazarf123/powershell-ad-m365-scripts.git
cd powershell-ad-m365-scripts

# 3. Run any Graph script interactively (browser sign-in prompt will appear)
.\src\graph\Get-LicenseOptimizationReport.ps1

# 4. Run any AD script (requires RSAT ActiveDirectory module on Windows)
.\Get-ADGroupAudit.ps1
```

For unattended / scheduled runs, see the [Authentication Options](#authentication-options) section in any individual runbook.

---

## Authentication Options (Graph Scripts)

### Interactive (developer / one-off runs)
```powershell
# Browser sign-in; no stored credentials
.\src\graph\Get-LicenseOptimizationReport.ps1
```

### Certificate-Based App Registration (automation)
```powershell
$env:TENANT_ID       = "<tenant-guid>"
$env:APP_CLIENT_ID   = "<app-client-id>"
$env:CERT_THUMBPRINT = "<cert-thumbprint>"

Connect-MgGraph -ClientId $env:APP_CLIENT_ID `
                -TenantId $env:TENANT_ID `
                -CertificateThumbprint $env:CERT_THUMBPRINT -NoWelcome

.\src\graph\Get-IntuneDeviceCompliance.ps1
```

### Managed Identity (Azure-hosted workloads)
```powershell
Connect-MgGraph -Identity
.\src\graph\Export-ConditionalAccessPolicies.ps1
```

---

## Sample Outputs

All sample outputs use fictional `contoso.com` data — no real tenant identifiers.

| Report | Sample File |
|--------|------------|
| License Optimization — Users | [LicenseOptimization_Users_sample.csv](../examples/LicenseOptimization_Users_sample.csv) |
| License Optimization — SKUs | [LicenseOptimization_SKUs_sample.csv](../examples/LicenseOptimization_SKUs_sample.csv) |
| Stale Guest Report | [StaleGuests_sample.csv](../examples/StaleGuests_sample.csv) |
| Conditional Access Policies | [ConditionalAccessPolicies_sample.csv](../examples/ConditionalAccessPolicies_sample.csv) |
| Intune Device Compliance | [IntuneDeviceCompliance_sample.csv](../examples/IntuneDeviceCompliance_sample.csv) |

---

## Running the Tests

```powershell
# Install Pester 5 (once)
Install-Module Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester .\tests\ -Output Detailed
```

---

## About

Built and maintained by **Elazar Ferrer** — IT Systems & Identity Administrator with hands-on experience managing enterprise AD, Microsoft 365, Entra ID, and Intune in healthcare-regulated environments.

🌐 Portfolio: [elazarf123.github.io/cyber-port](https://elazarf123.github.io/cyber-port)  
💼 LinkedIn: [linkedin.com/in/elazarf](https://linkedin.com/in/elazarf)  
📦 Repository: [github.com/elazarf123/powershell-ad-m365-scripts](https://github.com/elazarf123/powershell-ad-m365-scripts)

---

*[Repository README](../README.md) · [SECURITY.md](../SECURITY.md) · [CONTRIBUTING.md](../CONTRIBUTING.md) · [CHANGELOG.md](../CHANGELOG.md) · [LICENSE](../LICENSE)*
