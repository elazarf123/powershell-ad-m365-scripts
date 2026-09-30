# Active Directory & Microsoft 365 PowerShell Toolkit

PowerShell scripts for day-to-day identity administration and audit evidence: provisioning and auditing Active Directory, and reporting on Microsoft 365, Entra ID, and Intune through Microsoft Graph. Scripts that change anything support `-WhatIf`, and the Graph scripts are read-only unless you pass an explicit action switch.

## Scripts

### Active Directory (repo root)

| Script | What it does | Changes anything? |
| :--- | :--- | :--- |
| [`New-BulkADUsers.ps1`](New-BulkADUsers.ps1) | Creates AD users from a CSV, places each in its OU, sets a temporary password that must be changed at first logon, and logs results | Yes; supports `-WhatIf` |
| [`Get-ADStaleUsers.ps1`](Get-ADStaleUsers.ps1) | Finds enabled accounts with no logon in N days (default 90) and exports a CSV; `-DisableAccounts` disables them | Only with `-DisableAccounts`; supports `-WhatIf` |
| [`Get-ADGroupAudit.ps1`](Get-ADGroupAudit.ps1) | Lists group members with status, last logon, and department; `-IncludeNestedMembers` resolves nesting | No |
| [`Backup-AllGPOs.ps1`](Backup-AllGPOs.ps1) | Backs up every GPO to a timestamped folder with an HTML summary; optional ZIP and retention pruning | No (writes backups only) |
| [`Get-M365LicenseReport.ps1`](Get-M365LicenseReport.ps1) | Exports each user's M365 licenses and last sign-in via Graph | No |

### Microsoft Graph (`src/graph/`)

| Script | What it does | Graph scopes |
| :--- | :--- | :--- |
| [`Get-LicenseOptimizationReport.ps1`](src/graph/Get-LicenseOptimizationReport.ps1) | Flags inactive licensed users, E5 users who may only need E3, and over-provisioned SKUs | `User.Read.All`, `Organization.Read.All`, `AuditLog.Read.All` |
| [`Get-StaleGuestReport.ps1`](src/graph/Get-StaleGuestReport.ps1) | Finds B2B guests with no recent sign-in; optional `-DisableGuests` or `-RemoveGuests` | Read by default; `-WhatIf` / `-Confirm` on changes |
| [`Export-ConditionalAccessPolicies.ps1`](src/graph/Export-ConditionalAccessPolicies.ps1) | Exports every Conditional Access policy to CSV (optional JSON) as a baseline or audit evidence | `Policy.Read.All` |
| [`Get-IntuneDeviceCompliance.ps1`](src/graph/Get-IntuneDeviceCompliance.ps1) | Exports Intune device compliance with filters by state and platform | `DeviceManagementManagedDevices.Read.All`, `User.Read.All` |

### Shared helpers (`src/helpers/`)

- [`Write-Log.ps1`](src/helpers/Write-Log.ps1): leveled console and file logging
- [`Invoke-SafeAction.ps1`](src/helpers/Invoke-SafeAction.ps1): runs a change only when `-WhatIf` isn't set
- [`Write-EvidenceLog.ps1`](src/helpers/Write-EvidenceLog.ps1): append-only JSONL record of each state-changing action, for audit evidence

### Example workflow (`examples/`)

[`Invoke-UserOffboarding.ps1`](examples/Invoke-UserOffboarding.ps1) walks one user through offboarding across AD, Exchange Online, OneDrive, and M365 licensing, with a dry-run mode and an evidence trail.

Per-script documentation is in [`docs/`](docs/), and sample outputs are in [`examples/`](examples/).

## Quick start

Requirements: Windows PowerShell 5.1 or PowerShell 7, the ActiveDirectory module (RSAT) for AD scripts, and the Microsoft Graph PowerShell SDK for Graph scripts.

```powershell
git clone https://github.com/elazarf123/powershell-ad-m365-scripts.git
cd powershell-ad-m365-scripts

# Preview bulk user creation from the sample CSV without making changes
.\New-BulkADUsers.ps1 -CSVPath .\SampleUsers.csv -WhatIf

# Report accounts inactive 60+ days
.\Get-ADStaleUsers.ps1 -DaysInactive 60 -ExportPath .\StaleUsers.csv

# Export Conditional Access policies (read-only)
Connect-MgGraph -Scopes "Policy.Read.All"
.\src\graph\Export-ConditionalAccessPolicies.ps1 -ExportJson
```

## Tests

Pester tests for the helper functions are in [`tests/`](tests/). They use Pester 4 syntax.

```powershell
Install-Module Pester -RequiredVersion 4.10.1 -Scope CurrentUser -SkipPublisherCheck
Invoke-Pester .\tests
```

## Safety notes

- Run anything that changes directory state with `-WhatIf` first.
- Use certificate-based or delegated auth for Graph. Don't hardcode credentials.
- `New-BulkADUsers.ps1` has a default temporary password for lab use. Always pass your own with `-DefaultPassword` outside a lab.

See [`SECURITY.md`](SECURITY.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT
