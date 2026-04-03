# Contributing to EF_SYS PowerShell AD & M365 Scripts

Thank you for your interest in contributing. Contributions are welcome via pull requests. Please review the guidelines below before submitting changes.

---

## Folder Structure

| Folder | Contents |
|--------|----------|
| *(root)* | Legacy AD and GPO scripts (PowerShell 5.1+) |
| `src/graph/` | Microsoft Graph-based scripts (PowerShell 7.2+ preferred) |
| `src/helpers/` | Shared modules imported by `src/graph/` scripts |
| `tests/` | Pester 5 unit tests |
| `docs/` | Runbook-style documentation for each major script |
| `examples/` | Sanitized sample CSV/JSON outputs (no real tenant data) |

New Microsoft Graph scripts go in `src/graph/`. New AD/GPO scripts go in the root.

---

## Code Standards

- **PowerShell version:** Root-level scripts must be compatible with PowerShell 5.1+. Scripts under `src/graph/` should target PowerShell 7.2+ (use null-conditional operators `?.`, `??`, etc. where helpful) while remaining compatible with 5.1 where practical.
- **Comment-based help:** Every script must include a full comment-based help block with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, and `.NOTES` (Author, Version, Requires).
- **CmdletBinding:** All scripts should use `[CmdletBinding()]`. Scripts that modify data should include `SupportsShouldProcess` to enable `-WhatIf` / `-Confirm` support.
- **Error handling:** Use `try/catch` blocks around all AD and Graph API calls. Provide meaningful error messages and exit cleanly on unrecoverable errors.
- **Logging:** Scripts in `src/graph/` should use the shared `Write-Log` helper from `src/helpers/Write-Log.ps1`. Root-level scripts use `Write-Host` with `-ForegroundColor` for console feedback.
- **No hardcoded credentials:** Passwords, tokens, client secrets, and tenant IDs must never be committed. See [SECURITY.md](./SECURITY.md) for approved auth patterns.
- **Naming conventions:** Follow the approved PowerShell verb-noun naming standard (`Get-`, `New-`, `Export-`, `Backup-`). See the full verb list: `Get-Verb`.

---

## Testing Requirements

- Test all changes in a **non-production lab environment** before submitting a pull request.
- For scripts that modify AD objects (e.g., `New-BulkADUsers.ps1`, `Get-ADStaleUsers.ps1`), run with `-WhatIf` to verify intended behavior before live execution.
- Confirm that CSV-based scripts correctly validate required column headers and handle missing or malformed data without crashing.
- Verify that new parameters include proper help documentation and are reflected in `.PARAMETER` blocks.

---

## Security Considerations

- Do not introduce external dependencies unless absolutely necessary. If a new module is required, document it clearly in the `.NOTES` section and in the README Requirements table.
- Avoid storing or logging sensitive information (passwords, tokens, PII) in output files or console output.
- Scripts that disable or delete AD accounts must always support `-WhatIf` and include a confirmation prompt or clear warning before execution.
- Follow the principle of least privilege: request only the permissions each script genuinely needs.

---

## Pull Request Process

1. Fork the repository and create a feature branch (`feature/your-change`).
2. Make your changes following the standards above.
3. Update the relevant script's comment-based help if parameters or behavior change.
4. Update `README.md` if the change affects usage examples, prerequisites, or the requirements table.
5. Add an entry to `CHANGELOG.md` under an `[Unreleased]` section describing your change.
6. Open a pull request with a clear description of what was changed and why.

---

## Reporting Issues

If you find a bug or have a feature request, open a GitHub Issue with:
- The script name and version (from `.NOTES`)
- A description of the problem or enhancement
- Steps to reproduce (for bugs)
- Your PowerShell version (`$PSVersionTable`) and OS
