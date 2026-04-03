# Get-StaleGuestReport.ps1

> **Category:** Microsoft Graph | Identity Governance  
> **Module:** `Microsoft.Graph.Users`  
> **Minimum Scopes (report):** `User.Read.All`, `AuditLog.Read.All`  
> **Additional Scopes (write):** `User.ReadWrite.All` (required for `-DisableGuests` or `-RemoveGuests`)

---

## What Problem Does This Solve?

Microsoft 365 B2B guest accounts let external collaborators access SharePoint sites, Teams channels, and shared files. Over time these accounts accumulate — former vendors, old project contractors, and forgotten invitees — and remain active long after the collaboration ended. Stale guests are:

- **A security risk** — an inactive external account can still access shared resources and is less likely to be noticed if compromised.
- **A compliance gap** — many frameworks (HIPAA, NIST, SOC 2) require periodic access reviews of external users.
- **A license consideration** — some guest access patterns consume licenses.

This script identifies stale B2B guests (no sign-in beyond a threshold) and optionally disables or removes them, with full `-WhatIf` / `-Confirm` support for every destructive action.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 7.2+ recommended (5.1 compatible) |
| Module | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| Permissions | See scope table above |

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InactiveDays` | `int` | `90` | Days without sign-in to flag as stale |
| `ExportPath` | `string` | `.\StaleGuests_<date>.csv` | Output CSV path |
| `LogPath` | `string` | *(empty)* | Structured log file path |
| `DisableGuests` | `switch` | — | Disable stale accounts (supports `-WhatIf`) |
| `RemoveGuests` | `switch` | — | Permanently delete stale accounts (supports `-WhatIf`) |
| `Force` | `switch` | — | Skip confirmation prompts (use with caution) |

---

## Usage Examples

```powershell
# Report only — no changes
.\src\graph\Get-StaleGuestReport.ps1

# Use a 60-day threshold
.\src\graph\Get-StaleGuestReport.ps1 -InactiveDays 60

# Preview which accounts would be disabled (no changes)
.\src\graph\Get-StaleGuestReport.ps1 -DisableGuests -WhatIf

# Disable with per-account confirmation
.\src\graph\Get-StaleGuestReport.ps1 -DisableGuests -Confirm

# Remove stale guests (automated — use only in tested pipelines)
.\src\graph\Get-StaleGuestReport.ps1 -RemoveGuests -Force
```

---

## Output

| File | Description |
|------|-------------|
| `StaleGuests_<date>.csv` | Stale guest accounts with last sign-in, account state, invite status, and recommended action |

**Sample output:** [examples/StaleGuests_sample.csv](../examples/StaleGuests_sample.csv)

---

## Safe Execution Guidance

1. **Always run `-WhatIf` first** before using `-DisableGuests` or `-RemoveGuests` in production.
2. **Review the CSV** before taking action — verify no active collaborators are in the list.
3. **Disable before Remove** — disabling preserves the account and can be reversed; deletion puts the account in the recycle bin (restorable for 30 days).
4. **Communicate with stakeholders** — notify business owners of guest access reviews before actioning.

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `User.ReadWrite.All` denied | Scope not granted | Add the permission to the app registration or consent interactively with a Global Admin |
| All guests show "Never" for last sign-in | Missing `AuditLog.Read.All` | Grant the scope; requires Azure AD Premium P1 in the tenant |
| `Remove-MgUser` fails on some accounts | Accounts may have active licenses or group ownerships | Manually review in Entra ID; remove dependencies before deletion |
