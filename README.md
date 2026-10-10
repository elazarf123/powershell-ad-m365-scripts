# Active Directory & Entra ID PowerShell Toolkit

PowerShell and Microsoft Graph scripts that provision, audit, and offboard identities in Active Directory and Microsoft Entra ID, so routine access work is faster, repeatable, and leaves an audit trail.

## Results

Measured in a lab Entra ID tenant (free tier), October 2026.

| Project | Result |
| :--- | :--- |
| [Entra ID access lifecycle lab](iam-access-lifecycle/) | 5 access requests: 2 granted, 3 rejected (incl. self-approval / separation of duties). Access review of 9 users found **4 least-privilege violations**; after remediation the follow-up review found **0** |
| [Entra ID benchmark](entra-benchmark/) | **50 users provisioned in ~37 s** (avg of 3 runs) vs **~100 min** by hand (projected from 3 users timed at 2 min each). 50 users offboarded in ~26 s |

Evidence files (CSV reports and a JSONL audit log) are in each folder.

## How it works

- **Active Directory scripts** (repo root) create users from CSV, find stale accounts, audit group membership, and back up GPOs.
- **Microsoft Graph scripts** ([`src/graph/`](src/graph/)) report on licenses, stale guests, Conditional Access policies, and Intune compliance. They are read-only unless you pass an action switch.
- **Access lifecycle lab** ([`iam-access-lifecycle/`](iam-access-lifecycle/)) grants access only from approved tickets, reviews group membership against a role catalog, removes excess access, and offboards users.
- **Every change supports `-WhatIf`**, and state-changing actions are written to an append-only evidence log ([`src/helpers/`](src/helpers/)).
- **Offboarding example** ([`examples/Invoke-UserOffboarding.ps1`](examples/Invoke-UserOffboarding.ps1)) walks one user through AD, Exchange Online, OneDrive, and licensing with a dry-run mode.

| Script | What it does | Changes anything? |
| :--- | :--- | :--- |
| [`New-BulkADUsers.ps1`](New-BulkADUsers.ps1) | Creates AD users from CSV with a must-change temporary password | Yes; supports `-WhatIf` |
| [`Get-ADStaleUsers.ps1`](Get-ADStaleUsers.ps1) | Finds enabled accounts with no logon in N days (default 90) | Only with `-DisableAccounts` |
| [`Get-ADGroupAudit.ps1`](Get-ADGroupAudit.ps1) | Lists group members with status, last logon, department | No |
| [`Backup-AllGPOs.ps1`](Backup-AllGPOs.ps1) | Backs up every GPO with an HTML summary | No (writes backups) |
| [`Get-M365LicenseReport.ps1`](Get-M365LicenseReport.ps1) | Exports each user's licenses and last sign-in | No |
| [`Get-LicenseOptimizationReport.ps1`](src/graph/Get-LicenseOptimizationReport.ps1) | Flags inactive licensed users and over-provisioned SKUs | No |
| [`Get-StaleGuestReport.ps1`](src/graph/Get-StaleGuestReport.ps1) | Finds B2B guests with no recent sign-in | Only with `-DisableGuests` / `-RemoveGuests` |
| [`Export-ConditionalAccessPolicies.ps1`](src/graph/Export-ConditionalAccessPolicies.ps1) | Exports Conditional Access policies as a baseline | No |
| [`Get-IntuneDeviceCompliance.ps1`](src/graph/Get-IntuneDeviceCompliance.ps1) | Exports Intune device compliance | No |

Per-script docs are in [`docs/`](docs/); sample outputs are in [`examples/`](examples/).

## Tech stack

PowerShell 5.1 / 7 · Microsoft Graph PowerShell SDK · ActiveDirectory module (RSAT) · Pester

## Run it

```powershell
git clone https://github.com/elazarf123/powershell-ad-m365-scripts.git
cd powershell-ad-m365-scripts

# Preview bulk AD user creation without making changes
.\New-BulkADUsers.ps1 -CSVPath .\SampleUsers.csv -DefaultPassword (Read-Host "Temp password") -WhatIf

# Export Conditional Access policies (read-only)
Connect-MgGraph -Scopes "Policy.Read.All"
.\src\graph\Export-ConditionalAccessPolicies.ps1 -ExportJson

# Run the helper tests (Pester 4)
Install-Module Pester -RequiredVersion 4.10.1 -Scope CurrentUser -SkipPublisherCheck
Invoke-Pester .\tests
```

The lab folders have their own run steps: [access lifecycle](iam-access-lifecycle/#run-it), [benchmark](entra-benchmark/#run-it-yourself).

## What I learned

- **Disabled is not offboarded.** The access review caught a disabled account that still held 2 groups.
- **Test your own rules.** An early version of the review flagged that same account as "missing access" after cleanup; fixing it made the rule explicit: a disabled account should hold no access.
- **Lab limits are real.** Entra ID keeps deleted usernames for 30 days, so each benchmark run needs a unique tag, and the stale-account scan needs an Entra ID P1/P2 license.

## Roadmap

- Stale-account scan once a P1/P2 trial tenant is available
- Pester tests for the lifecycle lab review rules

See [`SECURITY.md`](SECURITY.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md). MIT licensed.

> Lab use only. Run anything that changes directory state with `-WhatIf` first, and never against a production tenant without approval.
