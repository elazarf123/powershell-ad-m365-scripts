# New-BulkADUsers.ps1

> **Category:** Active Directory | User Provisioning  
> **Module:** `ActiveDirectory` (RSAT)  
> **Minimum Rights:** Domain Admin or delegated account-creation rights in the target OUs

---

## What Problem Does This Solve?

Manually creating 10, 50, or 100 AD user accounts for a new-hire cohort is tedious, error-prone, and non-reproducible. Common mistakes include:

- Inconsistent naming conventions (first.last vs. flast)
- Wrong OU placement for the user's department
- Forgotten `ChangePasswordAtLogon` enforcement
- No audit trail of what was created

This script turns a structured CSV file into a repeatable, auditable provisioning run — completing in under 5 minutes what would otherwise take hours.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 5.1 or 7+ |
| Module | `ActiveDirectory` RSAT module |
| Rights | Domain Admin or delegated OU create-user permission |
| Input | CSV file matching the column structure in [SampleUsers.csv](../SampleUsers.csv) |

### Install RSAT (if needed)
```powershell
# Windows Server
Add-WindowsFeature RSAT-AD-PowerShell

# Windows 10/11 client
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

---

## Input CSV Format

The CSV must contain the following columns (see [SampleUsers.csv](../SampleUsers.csv) for a complete example):

| Column | Required | Description |
|--------|----------|-------------|
| `FirstName` | ✅ | User's first name |
| `LastName` | ✅ | User's last name |
| `Department` | ✅ | Department — used to determine OU placement |
| `JobTitle` | ✅ | Job title / position |
| `OU` | ✅ | Distinguished name of the target OU (e.g., `OU=Engineering,DC=corp,DC=local`) |
| `Email` | Optional | Sets the `EmailAddress` attribute if provided |

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `CSVPath` | `string` | `.\SampleUsers.csv` | Path to the input CSV file |
| `LogPath` | `string` | `.\BulkADUsers_Log_<timestamp>.csv` | Path for the results log |
| `DefaultPassword` | `string` | `Welcome1!` | Temporary password assigned to all new accounts |

---

## Usage Examples

```powershell
# Default run using the included sample CSV
.\New-BulkADUsers.ps1

# Custom CSV and log path
.\New-BulkADUsers.ps1 -CSVPath "C:\Imports\NewHires_2025-Q2.csv" `
                       -LogPath "C:\Logs\Provisioning_$(Get-Date -Format yyyyMMdd).csv"

# Preview mode — shows what would be created without making any changes
.\New-BulkADUsers.ps1 -WhatIf

# Custom temporary password
.\New-BulkADUsers.ps1 -CSVPath ".\hires.csv" -DefaultPassword "Temp@2025!"
```

---

## Output

| File | Description |
|------|-------------|
| `BulkADUsers_Log_<timestamp>.csv` | Per-user results: status (Created / Skipped / Failed), UPN, SamAccountName, OU, error detail |

---

## Safe Execution Guidance

1. **Always run `-WhatIf` first** against a test or staging environment before targeting production.
2. **Validate the CSV** — check for duplicate names, missing OUs, and correct department values before running.
3. **Verify OU paths** — if an OU does not exist, the script will log a failure for that user and continue.
4. **Rotate temporary passwords** — use a strong, environment-specific temporary password and notify users through a secure channel.
5. **Review the log** — confirm all accounts were created before closing the ticket.

---

## Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| `ActiveDirectory module not found` | RSAT not installed | Install RSAT (see Prerequisites above) |
| `Access denied to create object` | Insufficient OU permissions | Run as Domain Admin or delegate account-creation to the service account |
| `Duplicate samAccountName` | User with same name already exists | Script skips duplicates and logs the skip — review the log |
| `Path not found` for OU | OU DN is incorrect in the CSV | Verify the OU DN using `Get-ADOrganizationalUnit -Filter * | Select DistinguishedName` |
