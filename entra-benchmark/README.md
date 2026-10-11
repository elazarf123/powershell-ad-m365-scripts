# Entra ID User Lifecycle Benchmark

Measures how much time PowerShell + Microsoft Graph automation saves on everyday identity administration tasks, compared with doing the same work by hand in the Microsoft Entra admin portal.

Run in a **lab Microsoft Entra ID tenant** (free tier) on October 9, 2026.

## Results

|Task|Automated (avg of 3 runs)|By hand (measured)|
|-|-|-|
|Provision 50 users + group assignment|**\~37 seconds** (0.75 s/user)|\~100 minutes (2 min/user, projected from 3 users timed at 6 min)|
|Offboard (disable) 50 users|**\~26 seconds**|—|
|Nested group audit (25 users, 3 nested groups)|**< 0.5 seconds**|—|
|Stale-account scan (90+ days)|Skipped: requires Entra ID P1/P2|—|

Raw data for every run: [`AllRuns.csv`](AllRuns.csv)

|Run|Provision 50|Disable 50|Nested audit|
|-|-|-|-|
|1|33.05 s|24.04 s|0.35 s|
|2|38.28 s|26.82 s|0.43 s|
|3|40.75 s|26.20 s|0.51 s|

## How it was measured

1. **Manual baseline:** created 3 users by hand in the Entra portal (name, username, password, department, group assignment) with a stopwatch: 6 minutes total, 2 minutes per user.
2. **Automated:** ran `Invoke-EntraBenchmark.ps1 -UserCount 50` three times, cleaning up between runs, and averaged the results.
3. Times include real network round-trips to Microsoft Graph, so they reflect what an admin would actually experience.

## What the script does

* Generates a CSV of 50 test users and creates them with `New-MgUser`, forcing a password change at first sign-in
* Builds a chain of 3 nested groups (2 levels of nesting) and assigns half the users, then resolves membership with `Get-MgGroupTransitiveMember`
* Disables every test account (offboarding) with `Update-MgUser`
* Uses a unique run tag per run because Entra keeps deleted usernames for 30 days
* `-Cleanup` removes all test users and groups

## Run it yourself

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups -Scope CurrentUser
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.Read.All" -TenantId "<your-tenant>.onmicrosoft.com" -UseDeviceCode
.\Invoke-EntraBenchmark.ps1 -UserCount 5 -Domain "<your-tenant>.onmicrosoft.com"
.\Invoke-EntraBenchmark.ps1 -Cleanup -Domain "<your-tenant>.onmicrosoft.com"
```

> Lab use only. Never run against a production tenant.

