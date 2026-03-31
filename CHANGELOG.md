# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.0] — 2024-01-01

### Added

- **New-BulkADUsers.ps1** — Bulk provision AD users from a structured CSV file with per-user OU placement, temporary password assignment, `ChangePasswordAtLogon` enforcement, and timestamped results log. Supports `-WhatIf`.
- **Get-ADStaleUsers.ps1** — Detect enabled AD accounts inactive beyond a configurable threshold (default 90 days). Exports CSV report with last logon, department, manager, and days inactive. Optional `-DisableAccounts` switch with `-WhatIf` support.
- **Get-ADGroupAudit.ps1** — Enumerate all AD security and distribution groups; enrich each member record with enabled status, department, and last logon. Supports nested group resolution via `-IncludeNestedMembers` and scoped search via `-SearchBase`.
- **Get-M365LicenseReport.ps1** — Connect to Microsoft Graph and export a full license assignment report per user, including SKU-to-friendly-name mapping, available seats per SKU, last sign-in date, and optional unlicensed user inclusion.
- **Backup-AllGPOs.ps1** — Back up all domain GPOs to timestamped folders, generate an HTML summary report with color-coded status, support ZIP compression via `-CreateZip`, and auto-prune old backups via `-MaxBackups`.
- **SampleUsers.csv** — Sample input file for `New-BulkADUsers.ps1` demonstrating required column structure.
- **README.md** — Full documentation with usage examples, prerequisites, requirements table, and security best practices.
- **CONTRIBUTING.md** — Contribution guidelines, code standards, testing requirements, and security considerations.
- **LICENSE** — MIT License.

---

## [Unreleased]

_Changes staged for the next release will appear here._
