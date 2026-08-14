function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [string]$LogFile,
        [switch]$NoConsole
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $logEntry = "[$timestamp] [$Level] $Message"

    if (-not $NoConsole) {
        $color = switch ($Level) {
            'DEBUG'   { 'DarkGray' }
            'INFO'    { 'Cyan' }
            'WARN'    { 'Yellow' }
            'ERROR'   { 'Red' }
            'SUCCESS' { 'Green' }
            default   { 'White' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    if ($LogFile) {
        $logDir = Split-Path -Path $LogFile -Parent
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    }
}

function Write-LogBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [string]$LogFile
    )

    $line = "=" * 60
    Write-Log -Message $line -Level INFO -LogFile $LogFile
    Write-Log -Message " $Title" -Level INFO -LogFile $LogFile
    Write-Log -Message $line -Level INFO -LogFile $LogFile
}
