<#
.SYNOPSIS
    IAM access-lifecycle lab for Microsoft Entra ID: role-based access requests with approval
    checks, periodic access reviews, and offboarding, all with an audit trail.

.DESCRIPTION
    Simulates the daily work of a Security Administrator on a healthcare claims platform:

      -Action Setup     Builds a lab: role groups, 9 users, sample access-request tickets,
                        and a few deliberate access problems for the review to find.
      -Action Request   Processes tickets from access_requests.csv. A ticket is only granted if it is
                        Approved, the role exists, the user is active, and the approver is not the
                        requester or the user (separation of duties).
      -Action Review    Compares every user's actual group access to what their role allows and
                        writes a review report. Add -Remediate to remove excess access.
      -Action Offboard  Disables a user, revokes sessions, and removes all role access.
      -Action Cleanup   Deletes everything the lab created.

    Every change and every rejected request is written to iam_audit.jsonl.
    All changing actions support -WhatIf (preview without changing anything).

    Control mapping (NIST SP 800-53): AC-2 account management, AC-5 separation of duties,
    AC-6 least privilege, AU-2/AU-12 audit logging.

    LAB TENANT ONLY.

.EXAMPLE
    .\IAM-AccessLifecycle.ps1 -Action Setup
    .\IAM-AccessLifecycle.ps1 -Action Request -WhatIf
    .\IAM-AccessLifecycle.ps1 -Action Request
    .\IAM-AccessLifecycle.ps1 -Action Review
    .\IAM-AccessLifecycle.ps1 -Action Review -Remediate -WhatIf
    .\IAM-AccessLifecycle.ps1 -Action Offboard -User iam.mgarcia -Ticket TERM-2001
    .\IAM-AccessLifecycle.ps1 -Action Cleanup
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Setup','Request','Review','Offboard','Cleanup')][string]$Action,
    [string]$Domain = 'ferrerelazargmail.onmicrosoft.com',
    [string]$User,
    [string]$Ticket,
    [switch]$Remediate
)

Import-Module Microsoft.Graph.Users, Microsoft.Graph.Groups -ErrorAction Stop
if (-not (Get-MgContext)) { throw "Not connected. Run Connect-MgGraph first." }

$Here      = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$AuditLog  = Join-Path $Here 'iam_audit.jsonl'
$Requests  = Join-Path $Here 'access_requests.csv'
$Operator  = $env:USERNAME

# ---------- Role catalog: each role = the only groups it should have (least privilege) ----------
$Roles = @{
    'Claims-Processor'   = @('IAM-Claims-Read','IAM-Claims-Edit')
    'Claims-Supervisor'  = @('IAM-Claims-Read','IAM-Claims-Edit','IAM-Claims-Approve')
    'Billing-Specialist' = @('IAM-Billing-Read','IAM-Billing-Edit')
    'Security-Admin'     = @('IAM-Security-Admin')
}
$AllGroups = $Roles.Values | ForEach-Object { $_ } | Sort-Object -Unique

# ---------- Helpers ----------
function Write-Audit([string]$Event, [string]$Target, [string]$Detail, [string]$Result, [string]$TicketId = '') {
    if ($WhatIfPreference) { return }
    [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        operator  = $Operator
        event     = $Event
        ticket    = $TicketId
        target    = $Target
        detail    = $Detail
        result    = $Result
    } | ConvertTo-Json -Compress | Add-Content -Path $AuditLog
}
function Get-Upn([string]$Name) { if ($Name -like '*@*') { $Name } else { "$Name@$Domain" } }
function Get-LabUser([string]$Name) {
    Get-MgUser -Filter "userPrincipalName eq '$(Get-Upn $Name)'" -Property Id,UserPrincipalName,DisplayName,JobTitle,AccountEnabled -ErrorAction SilentlyContinue
}
function Get-LabGroup([string]$Name) { Get-MgGroup -Filter "displayName eq '$Name'" -Top 1 }
function Get-IamGroupsOf($UserId) {
    Get-MgUserMemberOf -UserId $UserId -All |
        Where-Object { $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group' -and
                       $_.AdditionalProperties['displayName'] -like 'IAM-*' } |
        ForEach-Object { [pscustomobject]@{ Id = $_.Id; Name = $_.AdditionalProperties['displayName'] } }
}
function Add-ToGroup($UserObj, [string]$GroupName, [string]$TicketId) {
    $g = Get-LabGroup $GroupName
    if ((Get-IamGroupsOf $UserObj.Id).Name -contains $GroupName) { return }
    if ($PSCmdlet.ShouldProcess("$($UserObj.UserPrincipalName)", "Add to $GroupName")) {
        New-MgGroupMember -GroupId $g.Id -DirectoryObjectId $UserObj.Id
        Write-Audit 'GroupAdd' $UserObj.UserPrincipalName $GroupName 'Success' $TicketId
    }
}
function Remove-FromGroup($UserObj, [string]$GroupId, [string]$GroupName, [string]$TicketId, [string]$Reason) {
    if ($PSCmdlet.ShouldProcess("$($UserObj.UserPrincipalName)", "Remove from $GroupName ($Reason)")) {
        Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/groups/$GroupId/members/$($UserObj.Id)/`$ref"
        Write-Audit 'GroupRemove' $UserObj.UserPrincipalName "$GroupName - $Reason" 'Success' $TicketId
    }
}

switch ($Action) {

# =====================================================================
'Setup' {
    foreach ($g in $AllGroups) {
        if (-not (Get-LabGroup $g)) {
            New-MgGroup -DisplayName $g -MailEnabled:$false -MailNickname ($g -replace '-','') -SecurityEnabled -Description 'IAM lab role group' | Out-Null
        }
    }
    # Name, Role, Department, Enabled
    $people = @(
        @('iam.jsmith','Claims-Processor','Claims',$true),
        @('iam.alopez','Claims-Processor','Claims',$true),
        @('iam.cjones','Claims-Processor','Claims',$true),
        @('iam.mgarcia','Claims-Processor','Claims',$true),
        @('iam.kpatel','Billing-Specialist','Billing',$true),
        @('iam.tnguyen','Billing-Specialist','Billing',$true),
        @('iam.bwhite','Billing-Specialist','Billing',$true),
        @('iam.rsec','Security-Admin','IT Security',$true),
        @('iam.dlee','','Claims',$true)   # new hire, no access until a ticket is approved
    )
    foreach ($p in $people) {
        if (Get-LabUser $p[0]) { Write-Host "Exists: $($p[0])"; continue }
        $pw = 'Lab!' + [guid]::NewGuid().ToString('N').Substring(0,10) + 'Aa1'
        $params = @{
            DisplayName = ($p[0] -replace 'iam\.','')
            UserPrincipalName = (Get-Upn $p[0])
            MailNickname = ($p[0] -replace '\.','')
            Department = $p[2]
            AccountEnabled = $true
            PasswordProfile = @{ Password = $pw; ForceChangePasswordNextSignIn = $true }
        }
        if ($p[1]) { $params.JobTitle = $p[1] }
        $u = New-MgUser @params
        if ($p[1]) { foreach ($g in $Roles[$p[1]]) { New-MgGroupMember -GroupId (Get-LabGroup $g).Id -DirectoryObjectId $u.Id } }
        Write-Host "Created $($p[0]) [$($p[1])]"
    }

    Write-Host "`nPlanting access problems for the review to find..." -ForegroundColor Yellow
    Start-Sleep 5
    # 1. Privilege creep: claims processor kept billing access from an old role
    New-MgGroupMember -GroupId (Get-LabGroup 'IAM-Billing-Edit').Id   -DirectoryObjectId (Get-LabUser 'iam.alopez').Id
    # 2. Excessive privilege: claims processor holds Security Admin
    New-MgGroupMember -GroupId (Get-LabGroup 'IAM-Security-Admin').Id -DirectoryObjectId (Get-LabUser 'iam.cjones').Id
    # 3. Terminated user disabled but never had access removed
    Update-MgUser -UserId (Get-LabUser 'iam.bwhite').Id -AccountEnabled:$false

    @(
        [pscustomobject]@{Ticket='REQ-1001';User='iam.dlee';   Role='Claims-Processor';  Type='New';   Requester='mgr.claims';Approver='dir.ops';   Status='Approved';Justification='New hire - claims team'}
        [pscustomobject]@{Ticket='REQ-1002';User='iam.kpatel'; Role='Security-Admin';    Type='Change';Requester='iam.kpatel';Approver='iam.kpatel';Status='Approved';Justification='Need admin to fix my own access'}
        [pscustomobject]@{Ticket='REQ-1003';User='iam.mgarcia';Role='Claims-Supervisor'; Type='Change';Requester='mgr.claims';Approver='';          Status='Pending'; Justification='Promotion - awaiting director'}
        [pscustomobject]@{Ticket='REQ-1004';User='iam.jsmith'; Role='Claims-Supervisor'; Type='Change';Requester='mgr.claims';Approver='dir.ops';   Status='Approved';Justification='Promotion to supervisor'}
        [pscustomobject]@{Ticket='REQ-1005';User='iam.tnguyen';Role='Billing-Admin';     Type='Change';Requester='mgr.billing';Approver='dir.ops';  Status='Approved';Justification='Role does not exist in catalog'}
    ) | Export-Csv $Requests -NoTypeInformation

    Write-Audit 'LabSetup' $Domain "Groups: $($AllGroups.Count), users: $($people.Count)" 'Success'
    Write-Host "`nSetup complete. Tickets written to $Requests" -ForegroundColor Green
}

# =====================================================================
'Request' {
    if (-not (Test-Path $Requests)) { throw "No access_requests.csv found. Run -Action Setup first." }
    $out = foreach ($r in Import-Csv $Requests) {
        $reason = $null
        $u = Get-LabUser $r.User
        if     ($r.Status -ne 'Approved')                       { $reason = "Not approved (status: $($r.Status))" }
        elseif (-not $r.Approver)                               { $reason = 'No approver recorded' }
        elseif ($r.Approver -eq $r.Requester -or $r.Approver -eq $r.User) { $reason = 'Separation of duties: approver cannot be the requester or the user' }
        elseif (-not $Roles.ContainsKey($r.Role))               { $reason = "Role '$($r.Role)' is not in the role catalog" }
        elseif (-not $u)                                        { $reason = 'User not found' }
        elseif (-not $u.AccountEnabled)                         { $reason = 'User account is disabled' }

        if ($reason) {
            Write-Audit 'RequestRejected' $r.User "$($r.Role): $reason" 'Rejected' $r.Ticket
            [pscustomobject]@{Ticket=$r.Ticket; User=$r.User; Role=$r.Role; Decision='REJECTED'; Reason=$reason}
            continue
        }

        $oldRole = $u.JobTitle
        foreach ($g in $Roles[$r.Role]) { Add-ToGroup $u $g $r.Ticket }
        if ($r.Type -eq 'Change' -and $oldRole -and $Roles.ContainsKey($oldRole)) {
            foreach ($g in ($Roles[$oldRole] | Where-Object { $Roles[$r.Role] -notcontains $_ })) {
                $gid = (Get-LabGroup $g).Id
                if ((Get-IamGroupsOf $u.Id).Name -contains $g) { Remove-FromGroup $u $gid $g $r.Ticket "role changed from $oldRole" }
            }
        }
        if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, "Set role to $($r.Role)")) {
            Update-MgUser -UserId $u.Id -JobTitle $r.Role
            Write-Audit 'RequestGranted' $r.User "$oldRole -> $($r.Role) (approved by $($r.Approver))" 'Success' $r.Ticket
        }
        [pscustomobject]@{Ticket=$r.Ticket; User=$r.User; Role=$r.Role; Decision='GRANTED'; Reason="Approved by $($r.Approver)"}
    }
    $out | Format-Table -AutoSize -Wrap
}

# =====================================================================
'Review' {
    $users = Get-MgUser -Filter "startswith(userPrincipalName,'iam.')" -All -Property Id,UserPrincipalName,JobTitle,AccountEnabled
    $findings = foreach ($u in $users) {
        $actual   = @(Get-IamGroupsOf $u.Id)
        $expected = if ($u.JobTitle -and $Roles.ContainsKey($u.JobTitle)) { $Roles[$u.JobTitle] } else { @() }

        if (-not $u.AccountEnabled) {   # disabled accounts should hold no access at all
            foreach ($g in $actual) {
                [pscustomobject]@{User=$u.UserPrincipalName; Role=$u.JobTitle; Enabled=$u.AccountEnabled; Finding='Disabled account still has access'; Group=$g.Name; GroupId=$g.Id; Action='Remove'} }
            continue
        }
        foreach ($g in $actual | Where-Object { $expected -notcontains $_.Name }) {
            $f = if ($g.Name -eq 'IAM-Security-Admin') { 'Excessive privilege (admin access outside role)' } else { 'Access not allowed by role (privilege creep)' }
            [pscustomobject]@{User=$u.UserPrincipalName; Role=$u.JobTitle; Enabled=$u.AccountEnabled; Finding=$f; Group=$g.Name; GroupId=$g.Id; Action='Remove'}
        }
        foreach ($m in $expected | Where-Object { ($actual.Name) -notcontains $_ }) {
            [pscustomobject]@{User=$u.UserPrincipalName; Role=$u.JobTitle; Enabled=$u.AccountEnabled; Finding='Missing access required by role'; Group=$m; GroupId=''; Action='Review'}
        }
    }

    $stamp  = Get-Date -Format 'yyyyMMdd-HHmm'
    $report = Join-Path $Here "AccessReview_$stamp.csv"
    if ($findings) { $findings | Select-Object User,Role,Enabled,Finding,Group,Action | Export-Csv $report -NoTypeInformation }
    else { [pscustomobject]@{User="(all $(@($users).Count) users)";Role="";Enabled="";Finding="No findings - every user matches their role";Group="";Action="None"} | Export-Csv $report -NoTypeInformation }
    Write-Host "`nUsers reviewed: $(@($users).Count)   Findings: $(@($findings).Count)" -ForegroundColor Cyan
    if ($findings) { $findings | Select-Object User,Role,Finding,Group,Action | Format-Table -AutoSize -Wrap }
    else { Write-Host 'No findings: every user matches their role.' -ForegroundColor Green }
    Write-Host "Report saved: $report"
    Write-Audit 'AccessReview' $Domain "Users: $(@($users).Count), findings: $(@($findings).Count), report: $report" 'Success'

    if ($Remediate) {
        foreach ($f in $findings | Where-Object Action -eq 'Remove') {
            $u = Get-LabUser $f.User
            Remove-FromGroup $u $f.GroupId $f.Group "REVIEW-$stamp" $f.Finding
        }
        if (-not $WhatIfPreference) { Write-Host "Remediation complete. Run -Action Review again to confirm." -ForegroundColor Green }
    }
}

# =====================================================================
'Offboard' {
    if (-not $User -or -not $Ticket) { throw "Offboard needs -User and -Ticket (e.g. -User iam.mgarcia -Ticket TERM-2001)." }
    $u = Get-LabUser $User
    if (-not $u) { throw "User $User not found." }
    if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Disable account')) {
        Update-MgUser -UserId $u.Id -AccountEnabled:$false
        Write-Audit 'AccountDisabled' $u.UserPrincipalName 'Offboarding' 'Success' $Ticket
    }
    if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Revoke all sign-in sessions')) {
        Invoke-MgGraphRequest -Method POST -Uri "v1.0/users/$($u.Id)/revokeSignInSessions" | Out-Null
        Write-Audit 'SessionsRevoked' $u.UserPrincipalName 'Offboarding' 'Success' $Ticket
    }
    foreach ($g in Get-IamGroupsOf $u.Id) { Remove-FromGroup $u $g.Id $g.Name $Ticket 'offboarding' }
    if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Mark role as Terminated')) {
        Update-MgUser -UserId $u.Id -JobTitle 'Terminated'
    }
    Write-Host "Offboarded $($u.UserPrincipalName) under $Ticket." -ForegroundColor Green
}

# =====================================================================
'Cleanup' {
    $users  = @(Get-MgUser -Filter "startswith(userPrincipalName,'iam.')" -All)
    $groups = @(Get-MgGroup -Filter "startswith(displayName,'IAM-')" -All)
    foreach ($u in $users)  { Remove-MgUser  -UserId  $u.Id
        try { Invoke-MgGraphRequest -Method DELETE -Uri "v1.0/directory/deletedItems/$($u.Id)" } catch { } }
    foreach ($g in $groups) { Remove-MgGroup -GroupId $g.Id }
    Write-Audit 'LabCleanup' $Domain "Removed users: $($users.Count), groups: $($groups.Count)" 'Success'
    Write-Host "Removed $($users.Count) users and $($groups.Count) groups." -ForegroundColor Green
}
}

