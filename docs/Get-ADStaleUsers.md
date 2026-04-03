# Get-ADStaleUsers.ps1

> **Category:** Active Directory | Account Hygiene  
> **Module:** `ActiveDirectory` (RSAT)  
> **Minimum Rights:** Domain read / Account Operator (+ disable rights for `-DisableAccounts`)

---

## What Problem Does This Solve?

Dormant AD accounts are a persistent security risk: former employees, contractors, and service accounts that were never disabled remain valid targets for credential attacks. Most compliance frameworks (HIPAA, NIST CSF 2.0, CIS Controls) require periodic review and remediation of inactive accounts.

This script automates that review by:

- Identifying every enabled account inactive beyond a configurable threshold (default: 90 days)
- Exporting a detailed CSV suitable for access-review evidence
- Optionally disabling flagged accounts with full `-WhatIf` support

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 5.1 or 7+ |
| Module | `ActiveDirectory` RSAT module |
| Rights | Domain read; Account Operator (or equivalent) if using `-DisableAccounts` |

### Install RSAT (if needed)
```powershell
# Windows Server
Add-WindowsFeature RSAT-AD-PowerShell

# Windows 10/11 client
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DaysInactive` | `int` | `90` | Days since last logon to flag an account as stale |
| `SearchBase` | `string` | *(entire domain)* | OU path to scope the search |
| `OutputPath` | `string` | `.\StaleUsers_<date>.csv` | Path for the exported CSV report |
| `DisableAccounts` | `switch` | — | Disables flagged accounts (supports `-WhatIf`) |

---

## Usage Examples

```powershell
# Report only — 90-day default threshold, no changes
.\Get-ADStaleUsers.ps1

# Use a 60-day threshold
.\Get-ADStaleUsers.ps1 -DaysInactive 60

# Scope to a specific OU
.\Get-ADStaleUsers.ps1 -SearchBase "OU=Contractors,DC=corp,DC=local"

# Preview which accounts would be disabled (no changes made)
.\Get-ADStaleUsers.ps1 -DisableAccounts -WhatIf

# Disable with per-account confirmation
.\Get-ADStaleUsers.ps1 -DisableAccounts -Confirm

# Full automation with custom threshold and output path
.\Get-ADStaleUsers.ps1 -DaysInactive 60 -DisableAccounts -Force `
    -OutputPath "\\FileServer\Audits\StaleUsers_$(Get-Date -Format yyyyMMdd).csv"
```

---

## Output

| File | Description |
|------|-------------|
| `StaleUsers_<date>.csv` | Stale account report: UPN, department, manager, last logon, days inactive, account status, action taken |

---

## Safe Execution Guidance

1. **Always run without `-DisableAccounts` first** — review the CSV output before taking action.
2. **Use `-WhatIf`** to preview which accounts would be disabled before committing.
3. **Exclude service accounts** — scope the search with `-SearchBase` to avoid disabling critical service accounts stored in non-user OUs.
4. **Communicate with managers** — before bulk-disabling, send the report to department heads to confirm accounts are genuinely inactive.
5. **Document the run** — retain the output CSV as compliance evidence for the review period.

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `ActiveDirectory module not found` | RSAT not installed | Install RSAT (see Prerequisites above) |
| `Access denied` on disable | Insufficient permissions | Run as Account Operator or Domain Admin |
| All accounts show same last logon | Replication lag | Wait for AD replication to complete; check `LastLogonDate` vs `LastLogon` attributes |
| Accounts not found in expected OU | Wrong `SearchBase` DN | Verify with `Get-ADOrganizationalUnit -Filter * | Select DistinguishedName` |
