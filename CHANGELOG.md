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

---

## [2.0.0] — 2025-04-03

### Added

- **src/graph/Get-LicenseOptimizationReport.ps1** — Advanced M365 license waste analysis via Microsoft Graph. Identifies inactive licensed users, high-cost SKU assignments for low-activity users, and over-provisioned SKUs. Exports per-user and per-SKU CSV reports.
- **src/graph/Get-StaleGuestReport.ps1** — B2B guest account hygiene via Microsoft Graph. Identifies external guests inactive beyond a configurable threshold. Supports `-DisableGuests` and `-RemoveGuests` with full `-WhatIf` / `-Confirm` safety.
- **src/graph/Export-ConditionalAccessPolicies.ps1** — Read-only Conditional Access policy audit/export. Exports all CA policies to CSV with state, assignments, grant controls, and session controls. Optional JSON archive for full-fidelity baselines.
- **src/graph/Get-IntuneDeviceCompliance.ps1** — Intune device compliance report via Microsoft Graph. Filterable by compliance state and OS platform. Flags non-compliant and stale check-in devices for remediation.
- **src/helpers/Write-Log.ps1** — Centralized logging module shared across all scripts. Provides `Initialize-Log`, `Write-Log`, `Write-LogBanner`, and `Write-LogSummary` functions with colour-coded console output and optional structured file logging.
- **tests/Write-Log.Tests.ps1** — Pester 5 unit tests for all logging helper functions.
- **examples/** — Sanitized sample CSV outputs for all four new scripts and the existing license report.
- **docs/** — Runbook-style documentation pages for each new script (prerequisites, auth options, parameters, examples, troubleshooting).
- **.gitignore** — Comprehensive ignore rules for PowerShell artefacts, OS files, credential files, output CSVs, and IDE settings.
- **SECURITY.md** — Security policy: no-secrets rule, recommended auth patterns (interactive, certificate, managed identity, Key Vault), least-privilege Graph scopes per script.

### Changed

- **README.md** — Upgraded to runbook standard: added installation steps, authentication options, least-privilege permissions table, folder structure overview, links to new scripts and docs.
- **CONTRIBUTING.md** — Updated to reflect PowerShell 7+ preferred target, new `src/` folder structure, and module import pattern.
