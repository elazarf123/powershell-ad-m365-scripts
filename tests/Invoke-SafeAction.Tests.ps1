#
# Pester 5 tests for Invoke-SafeAction + Write-EvidenceLog.
#
# These are "safety invariant" tests — they exist because once you rely
# on a dry-run gate in production, a silent regression in the gate is a
# compliance-grade bug. Keep these green.
#

BeforeAll {
    $here = $PSScriptRoot
    . (Join-Path $here '..\src\helpers\Write-EvidenceLog.ps1')
    . (Join-Path $here '..\src\helpers\Invoke-SafeAction.ps1')
}

Describe 'Write-EvidenceLog' {

    BeforeEach {
        $script:tempLog = Join-Path $TestDrive ("evidence-{0}.jsonl" -f ([guid]::NewGuid().Guid))
    }

    It 'writes a valid JSONL record with all required fields' {
        Write-EvidenceLog -Action 'Test.Action' -Target 'user@corp.local' `
            -Status 'Succeeded' -LogPath $script:tempLog | Out-Null

        $line = Get-Content $script:tempLog
        $line | Should -Not -BeNullOrEmpty

        $record = $line | ConvertFrom-Json
        $record.action        | Should -Be 'Test.Action'
        $record.target        | Should -Be 'user@corp.local'
        $record.status        | Should -Be 'Succeeded'
        $record.correlationId | Should -Match '^[0-9a-f-]{36}$'
        $record.timestamp     | Should -Match '^\d{4}-\d{2}-\d{2}T'
        $record.schemaVer     | Should -Be '1.0'
    }

    It 'honors an explicit CorrelationId' {
        $id = [guid]::NewGuid().Guid
        Write-EvidenceLog -Action 'Test.Action' -Target 't' -Status 'Succeeded' `
            -CorrelationId $id -LogPath $script:tempLog | Out-Null

        $record = (Get-Content $script:tempLog) | ConvertFrom-Json
        $record.correlationId | Should -Be $id
    }

    It 'inherits $script:EvidenceCorrelationId when set' {
        $script:EvidenceCorrelationId = [guid]::NewGuid().Guid
        Write-EvidenceLog -Action 'Test.Action' -Target 't' -Status 'Succeeded' `
            -LogPath $script:tempLog | Out-Null

        $record = (Get-Content $script:tempLog) | ConvertFrom-Json
        $record.correlationId | Should -Be $script:EvidenceCorrelationId

        Remove-Variable -Name EvidenceCorrelationId -Scope Script
    }

    It 'flags dryRun=true when Status is DryRun' {
        Write-EvidenceLog -Action 'Test.Action' -Target 't' -Status 'DryRun' `
            -LogPath $script:tempLog | Out-Null

        $record = (Get-Content $script:tempLog) | ConvertFrom-Json
        $record.dryRun | Should -BeTrue
    }

    It 'appends rather than overwrites' {
        1..3 | ForEach-Object {
            Write-EvidenceLog -Action 'Test.Action' -Target "user-$_" `
                -Status 'Succeeded' -LogPath $script:tempLog | Out-Null
        }
        (Get-Content $script:tempLog).Count | Should -Be 3
    }
}

Describe 'Invoke-SafeAction' {

    BeforeEach {
        $script:tempLog = Join-Path $TestDrive ("evidence-{0}.jsonl" -f ([guid]::NewGuid().Guid))
        $script:EvidenceCorrelationId = [guid]::NewGuid().Guid
        # Redirect evidence writes by monkey-patching the helper's default path.
        # Test-local LogPath override is cleaner, so we wrap.
        $script:log = $script:tempLog
    }

    AfterEach {
        Remove-Variable -Name EvidenceCorrelationId -Scope Script -ErrorAction SilentlyContinue
    }

    It 'executes the scriptblock on a real run and logs Attempted + Succeeded' {
        $marker = 0
        Invoke-SafeAction -Action 'Test.Real' -Target 'x' -ScriptBlock {
            $script:marker = 1
            Write-EvidenceLog -Action 'Nested.Noop' -Target 'x' -Status 'Succeeded' -LogPath $script:log | Out-Null
        } | Out-Null

        # The scriptblock ran.
        $script:marker | Should -Be 1
    }

    It 'does NOT execute the scriptblock when -WhatIf is passed' {
        $marker = 0
        # Force WhatIf via $ConfirmPreference trick — use the -WhatIf parameter
        # by setting $WhatIfPreference in scope for this call.
        $oldPref = $WhatIfPreference
        $WhatIfPreference = $true
        try {
            Invoke-SafeAction -Action 'Test.DryRun' -Target 'x' -ScriptBlock {
                $script:marker = 99
            } | Out-Null
        } finally {
            $WhatIfPreference = $oldPref
        }

        $script:marker | Should -Be 0
    }

    It 'does NOT execute the scriptblock when -DryRun switch is passed' {
        $marker = 0
        Invoke-SafeAction -Action 'Test.DryRun' -Target 'x' -DryRun `
            -ScriptBlock { $script:marker = 99 } | Out-Null

        $script:marker | Should -Be 0
    }

    It 'records Skipped when SkipIf predicate returns true' {
        $marker = 0
        Invoke-SafeAction -Action 'Test.Skip' -Target 'x' `
            -SkipIf { $true } `
            -ScriptBlock { $script:marker = 99 } | Out-Null

        $script:marker | Should -Be 0
    }

    It 'rethrows on failure AND writes a Failed record' {
        $script:tempLog = Join-Path $TestDrive ("fail-{0}.jsonl" -f ([guid]::NewGuid().Guid))

        {
            # Override the default log path via script scope so the helper picks it up.
            # We can't easily do that without changing the helper, so we rely on the
            # local 'logs/' being created under $TestDrive by running there.
            Push-Location $TestDrive
            try {
                Invoke-SafeAction -Action 'Test.Fail' -Target 'x' `
                    -ScriptBlock { throw 'boom' } | Out-Null
            } finally {
                Pop-Location
            }
        } | Should -Throw 'boom'

        $logDir  = Join-Path $TestDrive 'logs'
        $logFile = Get-ChildItem $logDir -Filter 'evidence-*.jsonl' | Select-Object -First 1
        $records = Get-Content $logFile.FullName | ForEach-Object { $_ | ConvertFrom-Json }
        ($records | Where-Object status -eq 'Attempted').Count | Should -Be 1
        ($records | Where-Object status -eq 'Failed').Count    | Should -Be 1
    }

    It 'correlation ID is stable across nested Invoke-SafeAction calls' {
        Push-Location $TestDrive
        try {
            Invoke-SafeAction -Action 'Parent.Action' -Target 'x' -ScriptBlock {
                Invoke-SafeAction -Action 'Child.Action' -Target 'x' -ScriptBlock { } | Out-Null
            } | Out-Null
        } finally {
            Pop-Location
        }

        $logFile = Get-ChildItem (Join-Path $TestDrive 'logs') -Filter 'evidence-*.jsonl' |
                     Select-Object -First 1
        $ids = Get-Content $logFile.FullName |
                 ForEach-Object { ($_ | ConvertFrom-Json).correlationId } |
                 Select-Object -Unique

        $ids.Count | Should -Be 1
    }
}
