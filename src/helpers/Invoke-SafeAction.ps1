<#
.SYNOPSIS
    Runs a state-changing operation behind a dry-run gate and an
    automatic evidence-log wrapper.

.DESCRIPTION
    Every script in this repo that mutates AD, Entra ID, Exchange, or
    SharePoint should route its destructive operations through
    Invoke-SafeAction. You get three things for free:

      1. Dry-run mode. Pass -WhatIf (or run under a script that declares
         SupportsShouldProcess) and the scriptblock does NOT execute —
         an evidence record with status='DryRun' is written instead.

      2. Evidence logging. Before the scriptblock runs an 'Attempted'
         record is written; after a 'Succeeded' or 'Failed' record is
         written with wall-clock duration. All three share one
         correlation ID so a full run can be replayed from the log.

      3. Exception safety. The scriptblock runs inside a try/catch so
         a partial failure is captured in the evidence log rather than
         lost to the console.

    Think of it as PowerShell's native ShouldProcess pattern, but with
    the audit trail baked in so you can't forget it.

.PARAMETER Action
    Verb-noun action identifier. Must match the Write-EvidenceLog
    convention (e.g. 'AD.DisableUser', 'M365.RevokeLicense').

.PARAMETER Target
    The object being operated on (UPN, DN, group name, SKU, etc.).

.PARAMETER ScriptBlock
    The actual work. Receives no arguments — capture variables from
    the enclosing scope. Return value is forwarded to the caller.

.PARAMETER Details
    Optional hashtable of context logged with the Attempted + terminal
    records (before/after values, parameters, ticket IDs, etc.).

.PARAMETER DryRun
    Force dry-run mode on this call, independent of -WhatIf. Useful
    when staging part of a run for review while letting the rest
    execute normally.

.PARAMETER SkipIf
    Optional predicate. If it returns $true, the action is recorded
    with status='Skipped' and the scriptblock is never executed.
    Use this for idempotent-by-design scripts (e.g. "skip if the user
    is already disabled") without cluttering the scriptblock itself.

.EXAMPLE
    # Inside a script that declares [CmdletBinding(SupportsShouldProcess)]:
    $script:EvidenceCorrelationId = [guid]::NewGuid().Guid

    Invoke-SafeAction -Action 'AD.DisableUser' -Target $upn `
        -Details @{ ou = $targetOu; reason = 'offboarding' } `
        -ScriptBlock { Disable-ADAccount -Identity $upn }

    # Run normally:   .\Invoke-UserOffboarding.ps1 -Upn jdoe@corp.local
    # Dress rehearsal: .\Invoke-UserOffboarding.ps1 -Upn jdoe@corp.local -WhatIf

.EXAMPLE
    # Idempotent skip:
    Invoke-SafeAction -Action 'AD.DisableUser' -Target $upn `
        -SkipIf { (Get-ADUser $upn).Enabled -eq $false } `
        -ScriptBlock { Disable-ADAccount -Identity $upn }
#>
function Invoke-SafeAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [hashtable]$Details,

        [switch]$DryRun,

        [scriptblock]$SkipIf
    )

    # Evaluate dry-run gate: explicit -DryRun OR the caller's -WhatIf.
    $isDryRun = [bool]$DryRun -or -not $PSCmdlet.ShouldProcess($Target, $Action)

    # Evaluate optional skip predicate.
    $shouldSkip = $false
    if ($SkipIf) {
        try {
            $shouldSkip = [bool](& $SkipIf)
        } catch {
            # If the predicate itself blows up, fail safe — treat as
            # "not skipped" so the scriptblock's own error handling
            # takes over. But log the predicate failure as context.
            Write-Warning "SkipIf predicate failed for $Action on $Target : $($_.Exception.Message)"
        }
    }

    if ($shouldSkip) {
        Write-EvidenceLog -Action $Action -Target $Target -Status 'Skipped' `
            -Details $Details -DryRun:$isDryRun | Out-Null
        return $null
    }

    if ($isDryRun) {
        Write-EvidenceLog -Action $Action -Target $Target -Status 'DryRun' `
            -Details $Details | Out-Null
        return $null
    }

    # Log the attempt first so we have a record even if PowerShell
    # itself crashes mid-operation.
    Write-EvidenceLog -Action $Action -Target $Target -Status 'Attempted' `
        -Details $Details | Out-Null

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = & $ScriptBlock
        $sw.Stop()

        Write-EvidenceLog -Action $Action -Target $Target -Status 'Succeeded' `
            -DurationMs ([int]$sw.ElapsedMilliseconds) -Details $Details | Out-Null

        return $result
    } catch {
        $sw.Stop()

        Write-EvidenceLog -Action $Action -Target $Target -Status 'Failed' `
            -DurationMs ([int]$sw.ElapsedMilliseconds) -Details $Details `
            -ErrorMessage $_.Exception.Message | Out-Null

        # Re-throw so calling script can decide stop/continue policy.
        throw
    }
}

Export-ModuleMember -Function Invoke-SafeAction -ErrorAction SilentlyContinue
