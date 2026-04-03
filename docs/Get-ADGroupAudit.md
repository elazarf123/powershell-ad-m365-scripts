# Get-ADGroupAudit.ps1

> **Category:** Active Directory | Access Reviews  
> **Module:** `ActiveDirectory` (RSAT)  
> **Minimum Rights:** Domain read (no write operations)

---

## What Problem Does This Solve?

Quarterly group-membership access reviews are a requirement in most security frameworks (SOC 2 CC6.3, HIPAA § 164.312, NIST AC-2). Manually generating evidence by expanding groups in ADUC is slow, inconsistent, and doesn't capture enriched data (account status, last logon, department) needed for an effective review.

This script automates the entire evidence-gathering process:

- Enumerates all AD security and distribution groups (or a filtered subset)
- Resolves direct and, optionally, nested memberships
- Enriches each member record with enabled status, department, manager, and last logon
- Exports a single, flat CSV ready for a compliance reviewer or access-review workflow

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 5.1 or 7+ |
| Module | `ActiveDirectory` RSAT module |
| Rights | Domain read — no write permissions required |

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
| `SearchBase` | `string` | *(entire domain)* | OU path to scope the group search |
| `GroupFilter` | `string` | `*` | Wildcard filter on group name (e.g., `IT-*`, `VPN-*`) |
| `OutputPath` | `string` | `.\ADGroupAudit_<timestamp>.csv` | Path for the exported CSV report |
| `IncludeNestedMembers` | `switch` | — | Recursively resolve nested group membership |

---

## Usage Examples

```powershell
# Full domain audit — all groups, direct membership only
.\Get-ADGroupAudit.ps1

# Target a specific group prefix
.\Get-ADGroupAudit.ps1 -GroupFilter "IT-*"

# Include nested group members
.\Get-ADGroupAudit.ps1 -IncludeNestedMembers

# Scope to a specific OU and save to a custom path
.\Get-ADGroupAudit.ps1 -SearchBase "OU=Security Groups,DC=corp,DC=local" `
                        -OutputPath "C:\Audits\GroupAudit_$(Get-Date -Format yyyyMMdd).csv"

# Filter by prefix and resolve nested groups — ideal for compliance evidence
.\Get-ADGroupAudit.ps1 -GroupFilter "IT-Admin-*" -IncludeNestedMembers `
                        -OutputPath "\\FileServer\Compliance\IT_Admin_Audit.csv"
```

---

## Output

| File | Description |
|------|-------------|
| `ADGroupAudit_<timestamp>.csv` | Flat membership export: group name, member name, UPN, object type, account enabled, department, last logon, days inactive |

---

## Understanding the Report

| Column | Description |
|--------|-------------|
| `GroupName` | Name of the AD group |
| `GroupType` | Security or Distribution |
| `MemberName` | Display name of the member |
| `MemberUPN` | User principal name |
| `ObjectType` | User, Computer, or Group (for nested) |
| `AccountEnabled` | `True` / `False` — disabled accounts in privileged groups are a red flag |
| `Department` | Department attribute from AD |
| `LastLogonDate` | Last interactive logon (replicated) |
| `DaysInactive` | Days since last logon |

---

## Compliance Use Cases

| Framework | Control | How This Script Helps |
|-----------|---------|----------------------|
| SOC 2 | CC6.3 — Logical access is reviewed periodically | Provides flat, reviewable group membership export |
| HIPAA | § 164.312(a)(1) — Access control | Documents who has access to what; supports access reviews |
| NIST CSF | PR.AC-4 — Access permissions managed | Evidence of periodic review and remediation |
| CIS Controls | Control 6 — Access Control Management | Supports user access review and revocation workflow |

---

## Safe Execution Guidance

1. **This script is read-only** — no changes are made to AD regardless of parameters used.
2. **Schedule quarterly** — most frameworks require at least annual reviews; quarterly is recommended.
3. **Retain output files** — store the CSVs in an access-controlled location as compliance evidence.
4. **Combine with `Get-ADStaleUsers.ps1`** — cross-reference group membership with stale account data to identify inactive members who still have privileged access.

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `ActiveDirectory module not found` | RSAT not installed | Install RSAT (see Prerequisites above) |
| Very slow on large domains | Nested member resolution across thousands of groups | Scope with `-SearchBase` and `-GroupFilter`; use a DC with good connectivity |
| `Access denied` reading some groups | Protected groups (AdminSDHolder) may require elevated rights | Run as Domain Admin or use a read-all service account |
| Empty output CSV | No groups match the filter in the SearchBase | Verify filter and SearchBase DN with `Get-ADGroup -Filter * -SearchBase <OU>` |
