$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Resolve-Path "$here/../src/helpers/Invoke-SafeAction.ps1").Path

Describe "Invoke-SafeAction Helper Tests" {
    BeforeEach {
        . $sut
    }

    It "Should execute scriptblock when WhatIf is not passed" {
        $tracker = @{ executed = $false }
        Invoke-SafeAction -ActionDescription "Test Action" -Target "TestTarget" -ScriptBlock {
            $tracker.executed = $true
        }
        $tracker.executed | Should Be $true
    }

    It "Should not execute scriptblock when WhatIf is passed" {
        $tracker = @{ executed = $false }
        Invoke-SafeAction -ActionDescription "Test Action" -Target "TestTarget" -WhatIf -ScriptBlock {
            $tracker.executed = $true
        }
        $tracker.executed | Should Be $false
    }
}
