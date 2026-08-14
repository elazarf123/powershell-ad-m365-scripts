function Invoke-SafeAction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionDescription,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [string]$LogFile
    )

    if ($PSCmdlet.ShouldProcess($Target, $ActionDescription)) {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Message "[EXECUTE] $ActionDescription -> $Target" -Level INFO -LogFile $LogFile
        } else {
            Write-Host "[EXECUTE] $ActionDescription -> $Target" -ForegroundColor Green
        }
        & $ScriptBlock
    } else {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Message "[WHATIF] Would execute: $ActionDescription -> $Target" -Level WARN -LogFile $LogFile
        } else {
            Write-Host "[WHATIF] Would execute: $ActionDescription -> $Target" -ForegroundColor Yellow
        }
    }
}
