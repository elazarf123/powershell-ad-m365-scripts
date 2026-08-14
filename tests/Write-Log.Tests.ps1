$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Resolve-Path "$here/../src/helpers/Write-Log.ps1").Path

Describe "Write-Log Helper Tests" {
    BeforeEach {
        . $sut
        $global:testLogFile = "$env:TEMP/test_log_$(Get-Random).log"
    }

    AfterEach {
        if (Test-Path $global:testLogFile) {
            Remove-Item $global:testLogFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Should write log entries without throwing" {
        { Write-Log -Message "Test message" -Level INFO } | Should Not Throw
    }

    It "Should write to log file when LogFile is specified" {
        Write-Log -Message "File write test" -Level WARN -LogFile $global:testLogFile -NoConsole
        (Test-Path $global:testLogFile) | Should Be $true
        $content = Get-Content $global:testLogFile
        $content -match "File write test" | Should Be $true
    }

    It "Should output banner lines with Write-LogBanner" {
        { Write-LogBanner -Title "TEST SUITE BANNER" } | Should Not Throw
    }
}
