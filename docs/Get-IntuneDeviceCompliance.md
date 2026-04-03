# Get-IntuneDeviceCompliance.ps1

> **Category:** Microsoft Intune | Endpoint Management  
> **Module:** `Microsoft.Graph.DeviceManagement`  
> **Minimum Scopes:** `DeviceManagementManagedDevices.Read.All`, `User.Read.All`

---

## What Problem Does This Solve?

In a Zero Trust security model, device compliance is a gate for accessing corporate resources. Non-compliant or stale devices that haven't checked in with Intune may have outdated policies, missing security updates, or disabled controls — making them a risk to the environment.

This script gives you:

- A **full inventory** of all Intune-managed devices with compliance state
- Flagged **non-compliant and unknown-state** devices for immediate remediation focus
- Devices with **stale check-ins** (no contact in 30+ days) that may need to be wiped or re-enrolled
- Filterable by compliance state and OS platform for targeted reporting

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 7.2+ recommended (5.1 compatible) |
| Module | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| Permissions | `DeviceManagementManagedDevices.Read.All`, `User.Read.All` |
| Intune license | Microsoft Intune Plan 1 or higher is required in the tenant |

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ExportPath` | `string` | `.\IntuneDeviceCompliance_<date>.csv` | Output CSV path |
| `ComplianceFilter` | `string` | `All` | Filter: `All`, `Compliant`, `NonCompliant`, `Unknown`, `Error`, `InGracePeriod` |
| `PlatformFilter` | `string` | `All` | Filter: `All`, `Windows`, `iOS`, `Android`, `macOS` |
| `LogPath` | `string` | *(empty)* | Structured log file path |

---

## Usage Examples

```powershell
# Full report — all devices, all platforms
.\src\graph\Get-IntuneDeviceCompliance.ps1

# Non-compliant devices only — targeted remediation list
.\src\graph\Get-IntuneDeviceCompliance.ps1 -ComplianceFilter NonCompliant `
    -ExportPath "C:\Reports\NonCompliant_$(Get-Date -Format yyyyMMdd).csv"

# Windows devices only
.\src\graph\Get-IntuneDeviceCompliance.ps1 -PlatformFilter Windows

# Monthly full report with logging
.\src\graph\Get-IntuneDeviceCompliance.ps1 `
    -ExportPath "\\FileServer\Intune\Compliance_$(Get-Date -Format yyyyMMdd).csv" `
    -LogPath "C:\Logs\Intune_$(Get-Date -Format yyyyMMdd).log"
```

---

## Output

| File | Description |
|------|-------------|
| `IntuneDeviceCompliance_<date>.csv` | Device inventory: name, user, OS, compliance state, last check-in, encryption, jailbreak status |

**Sample output:** [examples/IntuneDeviceCompliance_sample.csv](../examples/IntuneDeviceCompliance_sample.csv)

---

## Understanding Compliance States

| State | Meaning | Recommended Action |
|-------|---------|-------------------|
| `compliant` | Device meets all Intune compliance policies | No action required |
| `noncompliant` | Device violates one or more compliance policies | Investigate; notify user; remediate |
| `inGracePeriod` | Compliance policies applied but grace period active | Monitor; enforce before period expires |
| `unknown` | Device hasn't reported compliance state | Check enrolment; may need re-enrol |
| `error` | Intune couldn't evaluate the device | Review device in Intune portal |

---

## Stale Check-In Flag

The `StaleCheckIn` column is set to `True` for devices that have not contacted Intune in 30+ days. These devices:
- May not have received the latest compliance policies
- May have outdated configurations or missing security updates
- Should be reviewed for retirement or re-enrolment

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `Insufficient privileges` | Missing `DeviceManagementManagedDevices.Read.All` | Add to app registration; requires Intune admin consent |
| 0 devices returned | No Intune-enrolled devices or wrong tenant | Verify Intune is configured and devices are enrolled |
| `SignInActivity` null | Not a user scope issue — devices use a different field | Expected; `LastSyncDateTime` is used for device check-in |
