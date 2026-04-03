<#
.SYNOPSIS
    Pester tests for the Write-Log helper module (src/helpers/Write-Log.ps1).

.DESCRIPTION
    Validates the centralized logging helper functions:
      - Initialize-Log  : creates the log file with a header
      - Write-Log       : writes entries at correct severity and to file
      - Write-LogBanner : outputs the banner without errors
      - Write-LogSummary: outputs structured summary data

    Run with:
        Invoke-Pester .\tests\Write-Log.Tests.ps1 -Output Detailed

.NOTES
    Author:  Elazar Ferrer
    Requires: Pester 5.x  (Install-Module Pester -Force -SkipPublisherCheck)
#>

BeforeAll {
    # Import the module under test
    $modulePath = Join-Path $PSScriptRoot "..\src\helpers\Write-Log.ps1"
    Import-Module $modulePath -Force
}

Describe "Initialize-Log" {

    BeforeEach {
        $script:TestLogFile = Join-Path $TestDrive "test_run.log"
    }

    AfterEach {
        # Reset module-level log path between tests
        & (Get-Module -Name Write-Log -ErrorAction SilentlyContinue) { $script:LogFilePath = $null } 2>$null
        if (Test-Path $script:TestLogFile) { Remove-Item $script:TestLogFile -Force }
    }

    It "Creates the log file at the specified path" {
        Initialize-Log -LogPath $script:TestLogFile -ScriptName "TestScript"
        $script:TestLogFile | Should -Exist
    }

    It "Creates parent directories if they do not exist" {
        $deepPath = Join-Path $TestDrive "nested\dir\test.log"
        Initialize-Log -LogPath $deepPath -ScriptName "TestScript"
        $deepPath | Should -Exist
    }

    It "Writes script name to the log header" {
        Initialize-Log -LogPath $script:TestLogFile -ScriptName "MyTestScript"
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "MyTestScript"
    }

    It "Writes the hostname to the log header" {
        Initialize-Log -LogPath $script:TestLogFile -ScriptName "Test"
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match $env:COMPUTERNAME
    }

    It "Overwrites an existing log file on each call" {
        Set-Content $script:TestLogFile -Value "OLD CONTENT"
        Initialize-Log -LogPath $script:TestLogFile -ScriptName "NewRun"
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Not -Match "OLD CONTENT"
    }
}

Describe "Write-Log" {

    BeforeEach {
        $script:TestLogFile = Join-Path $TestDrive "write_log_test.log"
        Initialize-Log -LogPath $script:TestLogFile -ScriptName "Pester"
    }

    It "Writes an INFO entry to the log file" {
        Write-Log "Test info message" -Level INFO
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "\[INFO\] Test info message"
    }

    It "Writes a SUCCESS entry to the log file" {
        Write-Log "All done" -Level SUCCESS
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "\[SUCCESS\] All done"
    }

    It "Writes a WARNING entry to the log file" {
        Write-Log "Watch out" -Level WARNING
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "\[WARNING\] Watch out"
    }

    It "Writes an ERROR entry to the log file" {
        Write-Log "Something failed" -Level ERROR
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "\[ERROR\] Something failed"
    }

    It "Includes a timestamp in each log entry" {
        Write-Log "Timestamp test" -Level INFO
        $content = Get-Content $script:TestLogFile -Raw
        # Timestamp format: [yyyy-MM-dd HH:mm:ss]
        $content | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
    }

    It "Defaults to INFO level when no level is specified" {
        Write-Log "Default level test"
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "\[INFO\] Default level test"
    }

    It "Accepts pipeline input" {
        "Pipeline message" | Write-Log -Level SUCCESS
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "Pipeline message"
    }

    It "Does not throw for any valid level" {
        foreach ($level in @("INFO","SUCCESS","WARNING","ERROR")) {
            { Write-Log "Level $level test" -Level $level } | Should -Not -Throw
        }
    }

    It "Still writes to file when -NoConsole is specified" {
        Write-Log "Silent entry" -Level INFO -NoConsole
        $content = Get-Content $script:TestLogFile -Raw
        $content | Should -Match "Silent entry"
    }
}

Describe "Write-LogBanner" {

    It "Does not throw when called with a title" {
        { Write-LogBanner -Title "Test Banner" } | Should -Not -Throw
    }

    It "Does not throw for an empty-ish title" {
        { Write-LogBanner -Title " " } | Should -Not -Throw
    }
}

Describe "Write-LogSummary" {

    It "Does not throw when called with an ordered hashtable" {
        $data = [ordered]@{ "Key1" = "Value1"; "Key2" = 42 }
        { Write-LogSummary -Data $data } | Should -Not -Throw
    }

    It "Does not throw when called with a PSCustomObject" {
        $obj = [PSCustomObject]@{ Name = "Test"; Count = 5 }
        { Write-LogSummary -Data $obj } | Should -Not -Throw
    }

    It "Writes summary keys to the log file when Initialize-Log has been called" {
        $logFile = Join-Path $TestDrive "summary_test.log"
        Initialize-Log -LogPath $logFile -ScriptName "SummaryTest"
        Write-LogSummary -Data ([ordered]@{ "TotalUsers" = 100; "Inactive" = 12 })
        $content = Get-Content $logFile -Raw
        $content | Should -Match "TotalUsers"
        $content | Should -Match "100"
    }
}
