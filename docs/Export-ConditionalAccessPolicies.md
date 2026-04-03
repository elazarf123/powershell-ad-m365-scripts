# Export-ConditionalAccessPolicies.ps1

> **Category:** Microsoft Graph | Security & Identity  
> **Module:** `Microsoft.Graph.Identity.SignIns`  
> **Minimum Scopes:** `Policy.Read.All`

---

## What Problem Does This Solve?

Conditional Access is the core zero-trust enforcement mechanism in Microsoft Entra ID. Policies controlling MFA requirements, compliant-device mandates, and location-based restrictions are critical security controls — yet they can be modified or accidentally disabled with little visibility.

This script provides a **read-only, timestamped export** of every CA policy in the tenant for:

- **Pre-change baselines** — capture the policy state before any change window.
- **Post-change validation** — diff the before/after exports to verify only intended changes were made.
- **Compliance evidence** — SOC 2 / ISO 27001 / NIST CSF controls require documented access control policies.
- **Audit trail** — scheduled monthly exports provide a change history.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 7.2+ recommended (5.1 compatible) |
| Module | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| Permissions | `Policy.Read.All` — this is a **read-only** scope |
| Entra ID tier | Any (CA is available in all tiers, though P1 is required to create/edit policies) |

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ExportPath` | `string` | `.\ConditionalAccessPolicies_<date>.csv` | Output CSV path |
| `ExportJson` | `switch` | — | Also export raw policy JSON for full-fidelity archival |
| `LogPath` | `string` | *(empty)* | Structured log file path |
| `IncludeReportOnly` | `bool` | `$true` | Include report-only (non-enforced) policies |

---

## Usage Examples

```powershell
# Export all CA policies to CSV
.\src\graph\Export-ConditionalAccessPolicies.ps1

# Export with full-fidelity JSON archive
.\src\graph\Export-ConditionalAccessPolicies.ps1 -ExportPath "C:\Reports\CA_Baseline.csv" -ExportJson

# Monthly scheduled run with logging
.\src\graph\Export-ConditionalAccessPolicies.ps1 `
    -ExportPath "\\FileServer\Compliance\CA_$(Get-Date -Format yyyyMMdd).csv" `
    -ExportJson `
    -LogPath "C:\Logs\CA_Audit.log"

# Export enforced policies only (exclude report-only)
.\src\graph\Export-ConditionalAccessPolicies.ps1 -IncludeReportOnly $false
```

---

## Output Files

| File | Description |
|------|-------------|
| `ConditionalAccessPolicies_<date>.csv` | Flattened policy export: state, assignments, grant controls, session controls |
| `ConditionalAccessPolicies_<date>.json` | Full raw policy JSON (when `-ExportJson` is used) |

**Sample output:** [examples/ConditionalAccessPolicies_sample.csv](../examples/ConditionalAccessPolicies_sample.csv)

---

## Interpreting the Export

| Column | Description |
|--------|-------------|
| `State` | `enabled` / `disabled` / `enabledForReportingButNotEnforced` |
| `IncludeUsers` | `All` or specific user IDs/names |
| `GrantBuiltInControls` | e.g., `mfa`, `compliantDevice`, `domainJoinedDevice`, `block` |
| `SessionSignInFrequency` | How often users must re-authenticate |
| `SessionPersistentBrowser` | Whether browser sessions persist across sign-ins |

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `Insufficient privileges` | `Policy.Read.All` not granted | Add permission to app registration; Global Admin consent required |
| 0 policies returned | Wrong tenant or no CA policies exist | Verify you've consented in the correct tenant |
| JSON export is very large | Tenant has many complex policies | Normal — CA policy JSON is verbose; use `-ExportJson` only for archival runs |
