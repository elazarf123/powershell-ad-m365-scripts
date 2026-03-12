<#
.SYNOPSIS
    Audits Active Directory group memberships across the domain and exports results to CSV.

.DESCRIPTION
    Get-ADGroupAudit.ps1 enumerates AD security and distribution groups, then uses
    Get-ADGroupMember to retrieve each group's members. For every member it captures
    account status, last logon, and department. Results are exported to a timestamped
    CSV suitable for access reviews, compliance audits, and quarterly reporting.

.PARAMETER SearchBase
    The OU path to scope the group search. Defaults to the entire domain.

.PARAMETER GroupFilter
    A wildcard filter to target specific groups by name (e.g. "IT-*", "VPN-*").
    Defaults to '*' (all groups).

.PARAMETER OutputPath
    Path for the exported CSV report. Defaults to .\ADGroupAudit_<timestamp>.csv

.PARAMETER IncludeNestedMembers
    Switch to recursively resolve nested group membership.

.EXAMPLE
    .\Get-ADGroupAudit.ps1
    .\Get-ADGroupAudit.ps1 -GroupFilter "IT-*" -IncludeNestedMembers
    .\Get-ADGroupAudit.ps1 -SearchBase "OU=Groups,DC=corp,DC=local" -OutputPath "C:\Reports\Audit.csv"

.NOTES
    Author      : Elazar Ferrer
    Environment : Windows Server 2019, Active Directory Domain Services
    Requires    : ActiveDirectory PowerShell module (RSAT), read access to AD
    Version     : 1.0
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$SearchBase = (Get-ADDomain).DistinguishedName,

    [Parameter()]
    [string]$GroupFilter = '*',

    [Parameter()]
    [string]$OutputPath = ".\ADGroupAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",

    [Parameter()]
    [switch]$IncludeNestedMembers
)

#region --- Prerequisites ---

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT tools and try again."
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop

#endregion

#region --- Retrieve Groups ---

Write-Host "`n[INFO] Querying AD groups (filter: '$GroupFilter') under: $SearchBase" -ForegroundColor Cyan

try {
    $groups = Get-ADGroup -Filter { Name -like $GroupFilter } `
                          -SearchBase $SearchBase `
                          -Properties Description, GroupCategory, GroupScope, ManagedBy `
                          -ErrorAction Stop
}
catch {
    Write-Error "Failed to query AD groups: $($_.Exception.Message)"
    exit 1
}

Write-Host "[INFO] Found $($groups.Count) group(s) to audit.`n" -ForegroundColor Cyan

#endregion

#region --- Audit Memberships ---

$report = @()
$groupsProcessed = 0
$totalMembers    = 0

foreach ($group in $groups) {

    $groupsProcessed++
    Write-Progress -Activity "Auditing Groups" `
                   -Status "$($group.Name) ($groupsProcessed of $($groups.Count))" `
                   -PercentComplete (($groupsProcessed / $groups.Count) * 100)

    try {
        $memberArgs = @{ Identity = $group.DistinguishedName; ErrorAction = 'Stop' }
        if ($IncludeNestedMembers) { $memberArgs['Recursive'] = $true }

        $members = Get-ADGroupMember @memberArgs
    }
    catch {
        Write-Warning "Could not retrieve members of '$($group.Name)': $($_.Exception.Message)"
        $report += [PSCustomObject]@{
            GroupName      = $group.Name
            GroupCategory  = $group.GroupCategory
            GroupScope     = $group.GroupScope
            MemberCount    = 0
            MemberName     = 'N/A'
            MemberType     = 'N/A'
            SamAccountName = 'N/A'
            Enabled        = 'N/A'
            Department     = 'N/A'
            LastLogonDate  = 'N/A'
            Notes          = "Error: $($_.Exception.Message)"
        }
        continue
    }

    if ($members.Count -eq 0) {
        $report += [PSCustomObject]@{
            GroupName      = $group.Name
            GroupCategory  = $group.GroupCategory
            GroupScope     = $group.GroupScope
            MemberCount    = 0
            MemberName     = '(empty group)'
            MemberType     = 'N/A'
            SamAccountName = 'N/A'
            Enabled        = 'N/A'
            Department     = 'N/A'
            LastLogonDate  = 'N/A'
            Notes          = 'Group has no members'
        }
        Write-Host "  [EMPTY] $($group.Name)" -ForegroundColor DarkYellow
        continue
    }

    foreach ($member in $members) {

        $enabled      = 'N/A'
        $department   = 'N/A'
        $lastLogon    = 'N/A'
        $displayName  = $member.Name

        if ($member.objectClass -eq 'user') {
            try {
                $adUser = Get-ADUser -Identity $member.SamAccountName `
                                     -Properties Enabled, Department, LastLogonDate `
                                     -ErrorAction Stop
                $enabled     = $adUser.Enabled
                $department  = if ($adUser.Department) { $adUser.Department } else { 'Not Set' }
                $lastLogon   = if ($adUser.LastLogonDate) {
                                   $adUser.LastLogonDate.ToString('yyyy-MM-dd')
                               } else { 'Never' }
                $displayName = $adUser.Name
            }
            catch {
                $enabled = 'Lookup Error'
            }
        }

        $report += [PSCustomObject]@{
            GroupName      = $group.Name
            GroupCategory  = $group.GroupCategory
            GroupScope     = $group.GroupScope
            MemberCount    = $members.Count
            MemberName     = $displayName
            MemberType     = $member.objectClass
            SamAccountName = $member.SamAccountName
            Enabled        = $enabled
            Department     = $department
            LastLogonDate  = $lastLogon
            Notes          = ''
        }
        $totalMembers++
    }

    Write-Host "  [OK] $($group.Name) - $($members.Count) member(s)" -ForegroundColor Green
}

Write-Progress -Activity "Auditing Groups" -Completed

#endregion

#region --- Export Report ---

$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "`n--- Audit Summary ---" -ForegroundColor Yellow
Write-Host "  Groups audited : $groupsProcessed"  -ForegroundColor Cyan
Write-Host "  Total members  : $totalMembers"     -ForegroundColor Cyan
Write-Host "  Report saved   : $OutputPath"       -ForegroundColor Green
Write-Host ""

#endregion
