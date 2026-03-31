# Contributing to EF_SYS PowerShell AD & M365 Scripts

Thank you for your interest in contributing. Contributions are welcome via pull requests. Please review the guidelines below before submitting changes.

---

## Code Standards

- **PowerShell version:** All scripts must be compatible with PowerShell 5.1+. Avoid syntax or cmdlets that require PowerShell 7+.
- **Comment-based help:** Every script must include a full comment-based help block with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, and `.NOTES` (Author, Version, Requires).
- **CmdletBinding:** All scripts should use `[CmdletBinding()]`. Scripts that modify data should include `SupportsShouldProcess` to enable `-WhatIf` / `-Confirm` support.
- **Error handling:** Use `try/catch` blocks around all AD and Graph API calls. Provide meaningful error messages and exit cleanly on unrecoverable errors.
- **Output:** Use `Write-Host` with `-ForegroundColor` for console feedback. Use `Write-Warning` and `Write-Error` for non-fatal and fatal conditions, respectively.
- **No hardcoded credentials:** Passwords, tokens, and secrets must never be committed. Use parameters with `[SecureString]` where applicable.
- **Naming conventions:** Follow the approved PowerShell verb-noun naming standard (`Get-`, `New-`, `Backup-`). See the full verb list: `Get-Verb`.

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
