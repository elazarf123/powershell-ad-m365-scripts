<#
.SYNOPSIS
    Centralized logging helper for EF_SYS PowerShell scripts.

.DESCRIPTION
    Provides Write-Log and Initialize-Log functions used by all scripts in this
    repository. Produces colour-coded console output and an optional timestamped
    log file. Import this module at the top of any script with:

        Import-Module "$PSScriptRoot\..\helpers\Write-Log.ps1" -Force

.NOTES
    Author:  Elazar Ferrer
    Version: 1.0
    Requires: PowerShell 5.1+
#>

#region ── Module-level variables ──────────────────────────────────────────────

# Path to the active log file (set by Initialize-Log)
$script:LogFilePath = $null

#endregion

#region ── Public Functions ────────────────────────────────────────────────────

function Initialize-Log {
    <#
    .SYNOPSIS
        Creates (or clears) the log file and writes a run header.

    .PARAMETER LogPath
        Full path to the log file. Parent directory is created if it does not exist.

    .PARAMETER ScriptName
        Name of the calling script — written in the log header.

    .EXAMPLE
        Initialize-Log -LogPath "C:\Logs\Run_2025-01-15.log" -ScriptName "Get-StaleGuestReport"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogPath,

        [string]$ScriptName = "EF_SYS Script"
    )

    $script:LogFilePath = $LogPath

    # Ensure parent directory exists
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $separator = "=" * 60
    $header    = @"
$separator
  Script  : $ScriptName
  Started : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  Host    : $env:COMPUTERNAME
  User    : $env:USERNAME
$separator
"@
    Set-Content -Path $LogPath -Value $header -Encoding UTF8
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a structured log entry to the console and optionally to a file.

    .PARAMETER Message
        The message text to log.

    .PARAMETER Level
        Severity level. Accepted values: INFO, SUCCESS, WARNING, ERROR.
        Defaults to INFO.

    .PARAMETER NoConsole
        Suppresses console output. Entry is still written to the log file when
        Initialize-Log has been called.

    .EXAMPLE
        Write-Log "Connected to Microsoft Graph" -Level SUCCESS

    .EXAMPLE
        Write-Log "No devices found matching filter" -Level WARNING

    .EXAMPLE
        Write-Log "Graph API call failed: $_" -Level ERROR
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO",

        [switch]$NoConsole
    )

    process {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $entry     = "[$timestamp] [$Level] $Message"

        # ── Console output ────────────────────────────────────────────────────
        if (-not $NoConsole) {
            $color = switch ($Level) {
                "INFO"    { "Cyan"    }
                "SUCCESS" { "Green"   }
                "WARNING" { "Yellow"  }
                "ERROR"   { "Red"     }
                default   { "White"   }
            }

            $prefix = switch ($Level) {
                "INFO"    { "[*]" }
                "SUCCESS" { "[+]" }
                "WARNING" { "[!]" }
                "ERROR"   { "[X]" }
                default   { "   " }
            }

            Write-Host "$prefix $Message" -ForegroundColor $color
        }

        # ── File output ───────────────────────────────────────────────────────
        if ($script:LogFilePath) {
            Add-Content -Path $script:LogFilePath -Value $entry -Encoding UTF8
        }
    }
}

function Write-LogBanner {
    <#
    .SYNOPSIS
        Writes a styled banner header to the console (matches existing EF_SYS style).

    .PARAMETER Title
        Title text to display inside the banner.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Title
    )

    $line = "═" * 44
    Write-Host "`n╔$line╗"           -ForegroundColor Cyan
    Write-Host ("║  {0,-42}  ║" -f $Title) -ForegroundColor Cyan
    Write-Host "║  {0,-42}  ║" -f "Elazar Ferrer | EF_SYS" -ForegroundColor Cyan
    Write-Host "╚$line╝`n"           -ForegroundColor Cyan
}

function Write-LogSummary {
    <#
    .SYNOPSIS
        Writes a formatted summary block to the console (and log file if active).

    .PARAMETER Data
        An ordered hashtable or PSCustomObject whose keys/values are displayed.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Data
    )

    $separator = "═" * 38
    Write-Host "`n$separator" -ForegroundColor Cyan

    if ($Data -is [System.Collections.IDictionary]) {
        foreach ($key in $Data.Keys) {
            Write-Host ("  {0,-22}: {1}" -f $key, $Data[$key])
            if ($script:LogFilePath) {
                $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Add-Content $script:LogFilePath "[$ts] [SUMMARY] ${key}: $($Data[$key])" -Encoding UTF8
            }
        }
    }
    else {
        $Data.PSObject.Properties | ForEach-Object {
            Write-Host ("  {0,-22}: {1}" -f $_.Name, $_.Value)
        }
    }

    Write-Host "$separator`n" -ForegroundColor Cyan
}

#endregion

Export-ModuleMember -Function Initialize-Log, Write-Log, Write-LogBanner, Write-LogSummary
