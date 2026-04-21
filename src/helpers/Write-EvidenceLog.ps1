<#
.SYNOPSIS
    Writes a structured, append-only JSONL evidence record for every
    state-changing action performed by scripts in this repo.

.DESCRIPTION
    Evidence logs are the audit trail you hand to an auditor, a security
    reviewer, or your future self during an incident. Each line is a
    self-contained JSON object — grep-able, jq-able, SIEM-ingestible.

    Every record carries:
      - timestamp  (ISO 8601 UTC, millisecond precision)
      - correlationId (GUID that groups all steps of one logical run)
      - actor      (who ran the script — user@host)
      - action     (verb-noun identifier, e.g. 'AD.DisableUser')
      - target     (the object operated on, e.g. 'jdoe@corp.local')
      - status     ('DryRun' | 'Attempted' | 'Succeeded' | 'Failed' | 'Skipped')
      - dryRun     (bool — was this a dress-rehearsal run?)
      - durationMs (int — how long the action took)
      - details    (hashtable — freeform context)
      - error      (string — present only on Failed)
      - schemaVer  (string — evidence schema version, bumps on breaking change)

    The log file defaults to logs/evidence-<yyyyMMdd>.jsonl alongside the
    script's working directory, and rolls daily. Override with -LogPath.

.PARAMETER Action
    Required. A verb-noun action identifier. Keep it consistent across
    scripts so reporting queries work (e.g. always 'AD.DisableUser',
    never 'DisableAD' or 'AccountDisable').

.PARAMETER Target
    Required. The object the action was performed on — a UPN, DN, group
    name, license SKU, or whatever is meaningful for this action.

.PARAMETER Status
    Required. One of: DryRun, Attempted, Succeeded, Failed, Skipped.

.PARAMETER Details
    Optional hashtable of freeform context (before/after values, flags,
    parameters). Gets serialized as a nested object in the JSON record.

.PARAMETER ErrorMessage
    Optional. Include the exception message or reason on a Failed status.

.PARAMETER DurationMs
    Optional. Total wall-clock time the action took.

.PARAMETER CorrelationId
    Optional. Override the correlation ID. By default, uses
    $script:EvidenceCorrelationId if set, otherwise generates a new GUID.

.PARAMETER DryRun
    Optional. Explicitly flag this record as a dry-run. Automatically true
    if Status is 'DryRun'.

.PARAMETER LogPath
    Optional. Absolute path to the JSONL file. Defaults to
    ./logs/evidence-<yyyyMMdd>.jsonl

.EXAMPLE
    # Inside a script — set a correlation ID once per run, then log freely.
    $script:EvidenceCorrelationId = [guid]::NewGuid().Guid
    Write-EvidenceLog -Action 'AD.DisableUser' -Target 'jdoe@corp.local' `
        -Status 'Succeeded' -DurationMs 412 -Details @{ ou = 'Disabled Users' }

.EXAMPLE
    # Replay a run by filtering on correlation ID:
    Get-Content logs/evidence-20260421.jsonl |
      ConvertFrom-Json |
      Where-Object correlationId -eq '9f1a...' |
      Sort-Object timestamp
#>
function Write-EvidenceLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [ValidateSet('DryRun','Attempted','Succeeded','Failed','Skipped')]
        [string]$Status,

        [hashtable]$Details,

        [string]$ErrorMessage,

        [int]$DurationMs = 0,

        [string]$CorrelationId,

        [switch]$DryRun,

        [string]$LogPath
    )

    # Resolve correlation ID: explicit > script-scoped > new.
    if (-not $CorrelationId) {
        if ($script:EvidenceCorrelationId) {
            $CorrelationId = $script:EvidenceCorrelationId
        } else {
            $CorrelationId = [guid]::NewGuid().Guid
        }
    }

    # DryRun status implies DryRun=true.
    if ($Status -eq 'DryRun') { $DryRun = $true }

    # Resolve log path and ensure parent directory exists.
    if (-not $LogPath) {
        $logDir = Join-Path (Get-Location) 'logs'
        $LogPath = Join-Path $logDir ("evidence-{0}.jsonl" -f (Get-Date -Format 'yyyyMMdd'))
    }
    $logDir = Split-Path -Parent $LogPath
    if ($logDir -and -not (Test-Path $logDir)) {
        $null = New-Item -ItemType Directory -Path $logDir -Force
    }

    # Build the record.
    $record = [ordered]@{
        timestamp     = (Get-Date).ToUniversalTime().ToString('o')
        schemaVer     = '1.0'
        correlationId = $CorrelationId
        actor         = "$env:USERNAME@$env:COMPUTERNAME"
        action        = $Action
        target        = $Target
        status        = $Status
        dryRun        = [bool]$DryRun
        durationMs    = $DurationMs
    }
    if ($Details)      { $record.details = $Details }
    if ($ErrorMessage) { $record.error   = $ErrorMessage }

    # JSONL: one compact object per line.
    $json = $record | ConvertTo-Json -Depth 8 -Compress

    # Append atomically-ish. On Windows PowerShell Add-Content is not
    # strictly atomic across concurrent processes, but for single-host
    # script runs it's fine. If you need multi-host aggregation, ship
    # to Splunk / an API sink instead of the local file.
    Add-Content -Path $LogPath -Value $json -Encoding UTF8

    # Emit the record object so callers can inspect / pipe it.
    [pscustomobject]$record
}

# Export only the public function when dot-sourced into a module context.
Export-ModuleMember -Function Write-EvidenceLog -ErrorAction SilentlyContinue
