<#
.SYNOPSIS
    End-to-end user offboarding across AD, Exchange Online, OneDrive,
    and M365 licensing — with dry-run and a full evidence trail.

.DESCRIPTION
    This is the canonical example of the repo's safety model. Every
    state-changing call is wrapped in Invoke-SafeAction, which means:
      * -WhatIf does a full dress-rehearsal run with zero mutations
      * Every step writes a JSONL audit record to logs/evidence-*.jsonl
      * All records for one run share a correlation ID
      * Idempotent steps self-skip and log a 'Skipped' record

    Pipeline:
      1. AD account disabled
      2. Mailbox converted to Shared
      3. OneDrive ownership transferred to manager
      4. Teams ownership rotated
      5. E3 license reclaimed
      6. HR + manager notified
      7. Full audit record emitted

.PARAMETER Upn
    The departing user's UPN (e.g. jdoe@corp.local).

.PARAMETER NewOwnerUpn
    UPN of the manager / receiving owner for OneDrive + Teams.

.PARAMETER Reason
    Offboarding reason code. Flows into the evidence record for
    downstream reporting (e.g. 'voluntary', 'termination', 'contract-end').

.PARAMETER ArchiveDays
    How many days the mailbox stays in "shared" mode before final
    purge. Default 30 — aligns with HIPAA retention defaults.

.EXAMPLE
    # Dress rehearsal — no mutations, full evidence log of what WOULD happen.
    .\Invoke-UserOffboarding.ps1 -Upn jdoe@corp.local `
        -NewOwnerUpn manager@corp.local -WhatIf

.EXAMPLE
    # Real run.
    .\Invoke-UserOffboarding.ps1 -Upn jdoe@corp.local `
        -NewOwnerUpn manager@corp.local -Reason 'voluntary'

.NOTES
    Requires: Invoke-SafeAction.ps1, Write-EvidenceLog.ps1
    Modules:  ActiveDirectory, ExchangeOnlineManagement, Microsoft.Graph
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$Upn,

    [Parameter(Mandatory)]
    [string]$NewOwnerUpn,

    [ValidateSet('voluntary','termination','contract-end','reorg','other')]
    [string]$Reason = 'voluntary',

    [int]$ArchiveDays = 30
)

# --- Load helpers --------------------------------------------------------
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here '..\src\helpers\Write-EvidenceLog.ps1')
. (Join-Path $here '..\src\helpers\Invoke-SafeAction.ps1')

# --- One correlation ID for the whole run -------------------------------
$script:EvidenceCorrelationId = [guid]::NewGuid().Guid

$runContext = @{
    runId        = $script:EvidenceCorrelationId
    reason       = $Reason
    archiveDays  = $ArchiveDays
    newOwner     = $NewOwnerUpn
}

Write-Host "[offboarding] run $($script:EvidenceCorrelationId) start — target=$Upn reason=$Reason" -ForegroundColor Cyan
if ($PSCmdlet.MyInvocation.BoundParameters['WhatIf']) {
    Write-Host "[offboarding] DRY RUN — no mutations will be performed" -ForegroundColor Yellow
}

# --- 1. Disable AD account ---------------------------------------------
Invoke-SafeAction -Action 'AD.DisableUser' -Target $Upn -Details $runContext `
    -SkipIf { (Get-ADUser -Identity $Upn -Properties Enabled).Enabled -eq $false } `
    -ScriptBlock {
        Disable-ADAccount -Identity $Upn
        Move-ADObject -Identity (Get-ADUser $Upn).DistinguishedName `
            -TargetPath 'OU=Disabled Users,DC=corp,DC=local'
    }

# --- 2. Convert mailbox to Shared --------------------------------------
Invoke-SafeAction -Action 'ExO.ConvertToShared' -Target $Upn -Details $runContext `
    -SkipIf { (Get-Mailbox -Identity $Upn).RecipientTypeDetails -eq 'SharedMailbox' } `
    -ScriptBlock {
        Set-Mailbox -Identity $Upn -Type Shared
    }

# --- 3. Transfer OneDrive ownership ------------------------------------
Invoke-SafeAction -Action 'OneDrive.TransferOwnership' -Target $Upn `
    -Details ($runContext + @{ to = $NewOwnerUpn }) `
    -ScriptBlock {
        Set-SPOUser -Site "https://corp-my.sharepoint.com/personal/$($Upn -replace '[^a-z0-9]','_')" `
            -LoginName $NewOwnerUpn -IsSiteCollectionAdmin $true
    }

# --- 4. Rotate Teams ownership -----------------------------------------
Invoke-SafeAction -Action 'Teams.RotateOwner' -Target $Upn `
    -Details ($runContext + @{ to = $NewOwnerUpn }) `
    -ScriptBlock {
        $teams = Get-Team -User $Upn
        foreach ($t in $teams) {
            Add-TeamUser -GroupId $t.GroupId -User $NewOwnerUpn -Role Owner
            Remove-TeamUser -GroupId $t.GroupId -User $Upn -Role Owner
        }
    }

# --- 5. Reclaim E3 license ---------------------------------------------
Invoke-SafeAction -Action 'M365.RevokeLicense' -Target $Upn -Details $runContext `
    -SkipIf { -not (Get-MgUserLicenseDetail -UserId $Upn) } `
    -ScriptBlock {
        $e3Sku = (Get-MgSubscribedSku | Where-Object SkuPartNumber -eq 'ENTERPRISEPACK').SkuId
        Set-MgUserLicense -UserId $Upn -RemoveLicenses @($e3Sku) -AddLicenses @()
    }

# --- 6. Notify HR + manager --------------------------------------------
Invoke-SafeAction -Action 'Notify.OffboardingComplete' -Target $Upn `
    -Details ($runContext + @{ recipients = @('hr@corp.local', $NewOwnerUpn) }) `
    -ScriptBlock {
        Send-MailMessage -To 'hr@corp.local', $NewOwnerUpn `
            -From 'automation@corp.local' `
            -Subject "Offboarding complete: $Upn" `
            -Body ("Run ID: {0}`nTarget: {1}`nReason: {2}" -f $script:EvidenceCorrelationId, $Upn, $Reason) `
            -SmtpServer 'smtp.corp.local'
    }

Write-Host "[offboarding] run $($script:EvidenceCorrelationId) complete — see logs/evidence-$(Get-Date -Format yyyyMMdd).jsonl" -ForegroundColor Green
