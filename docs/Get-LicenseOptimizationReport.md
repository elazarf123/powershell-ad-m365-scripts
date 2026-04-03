# Get-LicenseOptimizationReport.ps1

> **Category:** Microsoft Graph | License Management  
> **Module:** `Microsoft.Graph.Users`, `Microsoft.Graph.Identity.DirectoryManagement`  
> **Minimum Scopes:** `User.Read.All`, `Organization.Read.All`, `AuditLog.Read.All`

---

## What Problem Does This Solve?

Microsoft 365 licenses are often the largest single line item in an IT budget. Over time, tenants accumulate waste from:

- Employees who resigned or went on extended leave but retain active license assignments
- Users assigned expensive E5 SKUs who only need E3 or Business Premium functionality
- Bulk license purchases made for headcount projections that never materialised

This script produces two actionable CSV reports — a **per-user analysis** and an **SKU-level inventory** — that give a license admin clear candidates for reclamation or downgrade.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 7.2+ recommended (5.1 compatible) |
| Module | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| Auth | Interactive (`Connect-MgGraph`) or certificate-based / Managed Identity for automation |
| Permissions | `User.Read.All`, `Organization.Read.All`, `AuditLog.Read.All` |

> **Note:** `AuditLog.Read.All` is required to read `SignInActivity` (last sign-in date). This permission requires an **Azure AD Premium P1** or higher licence in the tenant.

---

## Installation / First Run

```powershell
# 1. Install the Microsoft Graph PowerShell SDK (once per machine)
Install-Module Microsoft.Graph -Scope CurrentUser

# 2. Clone the repo or copy the script to your working directory

# 3. Run interactively
.\src\graph\Get-LicenseOptimizationReport.ps1
```

---

## Authentication Options

### Option A — Interactive (developer / one-off use)
```powershell
# The script calls Connect-MgGraph automatically.
# A browser window will open for sign-in.
.\src\graph\Get-LicenseOptimizationReport.ps1
```

### Option B — Certificate-Based App Registration (unattended / scheduled task)
```powershell
# Set environment variables (do NOT hardcode in the script)
$env:TENANT_ID        = "<your-tenant-id>"
$env:APP_CLIENT_ID    = "<app-registration-client-id>"
$env:CERT_THUMBPRINT  = "<certificate-thumbprint>"

Connect-MgGraph -ClientId $env:APP_CLIENT_ID `
                -TenantId $env:TENANT_ID `
                -CertificateThumbprint $env:CERT_THUMBPRINT

.\src\graph\Get-LicenseOptimizationReport.ps1
```

See [SECURITY.md](../SECURITY.md) for full guidance on secret-free authentication.

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ExportPath` | `string` | `.` (current dir) | Directory to save CSV reports |
| `InactiveDays` | `int` | `90` | Days of inactivity before flagging a user |
| `OverProvisionThreshold` | `int` | `10` | Minimum unused seats before flagging a SKU |
| `LogPath` | `string` | *(empty)* | Path for structured log file; omit for console-only |

---

## Usage Examples

```powershell
# Default run — saves to current directory, 90-day inactivity threshold
.\src\graph\Get-LicenseOptimizationReport.ps1

# Save to specific folder, flag users inactive 60+ days
.\src\graph\Get-LicenseOptimizationReport.ps1 -InactiveDays 60 -ExportPath "C:\Reports"

# Monthly automation with file logging
.\src\graph\Get-LicenseOptimizationReport.ps1 `
    -ExportPath "\\FileServer\LicenseReports" `
    -LogPath "C:\Logs\LicOpt_$(Get-Date -Format yyyyMMdd).log"
```

---

## Output Files

| File | Description |
|------|-------------|
| `LicenseOptimization_Users_<date>.csv` | Per-user breakdown: license names, last sign-in, inactive flag, recommendation |
| `LicenseOptimization_SKUs_<date>.csv` | Per-SKU breakdown: total, used, available seats, utilisation %, over-provision flag |

**Sample output:** [examples/LicenseOptimization_Users_sample.csv](../examples/LicenseOptimization_Users_sample.csv) | [examples/LicenseOptimization_SKUs_sample.csv](../examples/LicenseOptimization_SKUs_sample.csv)

---

## Troubleshooting

| Error | Likely Cause | Resolution |
|-------|-------------|------------|
| `Insufficient privileges to complete the operation` | Missing `AuditLog.Read.All` | Add the scope to the app registration or consent interactively |
| `SignInActivity is null` for all users | Tenant lacks AAD Premium P1 | Sign-in data requires Premium; the script will show "Never" and mark users inactive |
| Empty SKU report | No subscribed SKUs found | Verify the authenticating account is in the correct tenant |
| `Connect-MgGraph` browser doesn't open | Running in a headless/SSH session | Use certificate-based auth (Option B above) |
