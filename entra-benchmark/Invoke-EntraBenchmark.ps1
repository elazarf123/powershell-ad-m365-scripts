<#
.SYNOPSIS
    Times common identity admin tasks in a LAB Microsoft Entra ID tenant via Microsoft Graph,
    to quantify time saved versus manual administration.

.DESCRIPTION
    Tests (all objects are prefixed "bench." / "BM-" so they are easy to find and remove):
      1. Bulk provisioning  - creates N users from a generated CSV + assigns half to a group
      2. Stale-account scan - finds users with no sign-in in 90+ days
                              (needs Entra ID P1/P2 + AuditLog.Read.All; skipped automatically if unavailable)
      3. Nested group audit - resolves every user behind a 3-level nested group
      4. Bulk disable       - disables all test users (offboarding)
    Results print to screen and save to EntraBenchmarkResults.csv.

    LAB TENANT ONLY. Run -Cleanup when finished.

.EXAMPLE
    .\Invoke-EntraBenchmark.ps1 -UserCount 5
    .\Invoke-EntraBenchmark.ps1 -UserCount 50
    .\Invoke-EntraBenchmark.ps1 -Cleanup
#>
[CmdletBinding()]
param(
    [int]$UserCount = 50,
    [string]$Domain = 'ferrerelazargmail.onmicrosoft.com',
    [switch]$Cleanup
)

Import-Module Microsoft.Graph.Users, Microsoft.Graph.Groups -ErrorAction Stop
if (-not (Get-MgContext)) { throw "Not connected. Run Connect-MgGraph first." }

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result($Test, $Items, $Seconds) {
    $results.Add([pscustomobject]@{
        Test         = $Test
        Items        = $Items
        TotalSeconds = [math]::Round($Seconds, 2)
        PerItemSec   = if ($Items) { [math]::Round($Seconds / $Items, 3) } else { $null }
        RunAt        = Get-Date -Format 's'
    })
}
function Get-BenchUsers { Get-MgUser -Filter "startswith(userPrincipalName,'bench.user')" -All -Property Id,UserPrincipalName,AccountEnabled }
function Get-BenchGroup($Name) { Get-MgGroup -Filter "displayName eq '$Name'" -Top 1 }

# ---------- Cleanup ----------
if ($Cleanup) {
    $u = @(Get-BenchUsers)
    $u | ForEach-Object { Remove-MgUser -UserId $_.Id }
    $g = @(Get-MgGroup -Filter "startswith(displayName,'BM-')" -All)
    $g | ForEach-Object { Remove-MgGroup -GroupId $_.Id }
    Write-Host "Removed $($u.Count) users and $($g.Count) groups (users sit in Deleted users for 30 days)." -ForegroundColor Green
    return
}

if (@(Get-BenchUsers).Count -gt 0) { throw "Test users already exist. Run with -Cleanup first." }

# ---------- Setup: CSV + nested groups (App <- Dept <- Team) ----------
$csvPath = Join-Path $PSScriptRoot 'entra_benchmark_users.csv'
1..$UserCount | ForEach-Object {
    [pscustomobject]@{
        DisplayName = "Bench User $_"
        Upn         = "bench.user$_@$Domain"
        Nickname    = "bench.user$_"
        Department  = @('Claims','Billing','IT','Support')[$_ % 4]
    }
} | Export-Csv $csvPath -NoTypeInformation

$groups = @{}
foreach ($name in 'BM-App-Access','BM-Dept-Claims','BM-Team-A') {
    $groups[$name] = New-MgGroup -DisplayName $name -MailEnabled:$false -MailNickname ($name -replace '-','') -SecurityEnabled
}
New-MgGroupMember -GroupId $groups['BM-App-Access'].Id  -DirectoryObjectId $groups['BM-Dept-Claims'].Id
New-MgGroupMember -GroupId $groups['BM-Dept-Claims'].Id -DirectoryObjectId $groups['BM-Team-A'].Id

# ---------- Test 1: bulk provisioning ----------
$users = Import-Csv $csvPath
$created = [System.Collections.Generic.List[object]]::new()
$t = Measure-Command {
    foreach ($u in $users) {
        $pw = 'Tmp!' + [guid]::NewGuid().ToString('N').Substring(0,10) + 'Aa1'
        $created.Add((New-MgUser -DisplayName $u.DisplayName -UserPrincipalName $u.Upn -MailNickname $u.Nickname `
            -Department $u.Department -AccountEnabled `
            -PasswordProfile @{ Password = $pw; ForceChangePasswordNextSignIn = $true }))
    }
    $created | Select-Object -First ([math]::Ceiling($UserCount / 2)) | ForEach-Object {
        New-MgGroupMember -GroupId $groups['BM-Team-A'].Id -DirectoryObjectId $_.Id
    }
}
Add-Result 'Bulk provisioning (create + group assign)' $UserCount $t.TotalSeconds

# ---------- Test 2: stale-account scan (P1/P2 only) ----------
try {
    $stale = $null; $all = $null
    $t = Measure-Command {
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-90)
        $all = Get-MgUser -All -Property Id,UserPrincipalName,AccountEnabled,SignInActivity -ErrorAction Stop
        $stale = $all | Where-Object {
            $_.AccountEnabled -and (-not $_.SignInActivity.LastSignInDateTime -or $_.SignInActivity.LastSignInDateTime -lt $cutoff)
        }
    }
    Add-Result "Stale-account scan ($(@($stale).Count) flagged, includes never-signed-in)" @($all).Count $t.TotalSeconds
} catch {
    Write-Warning "Stale-account scan skipped: needs Entra ID P1/P2 and the AuditLog.Read.All scope. ($($_.Exception.Message))"
    Add-Result 'Stale-account scan (SKIPPED - needs Entra ID P1/P2)' 0 0
}

# ---------- Test 3: nested group audit ----------
$members = $null
$t = Measure-Command {
    $members = Get-MgGroupTransitiveMember -GroupId $groups['BM-App-Access'].Id -All |
        Where-Object { $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user' }
}
Add-Result "Nested group audit ($(@($members).Count) users resolved through 2 group levels)" @($members).Count $t.TotalSeconds

# ---------- Test 4: bulk disable ----------
$t = Measure-Command {
    foreach ($u in $created) { Update-MgUser -UserId $u.Id -AccountEnabled:$false }
}
Add-Result 'Bulk disable (offboarding)' $UserCount $t.TotalSeconds

# ---------- Output ----------
$results | Format-Table -AutoSize
$out = Join-Path $PSScriptRoot 'EntraBenchmarkResults.csv'
$results | Export-Csv $out -NoTypeInformation
Write-Host "`nSaved results to $out" -ForegroundColor Green
Write-Host "Run '.\Invoke-EntraBenchmark.ps1 -Cleanup' before your next run." -ForegroundColor Yellow
