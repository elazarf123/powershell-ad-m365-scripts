<#
.SYNOPSIS
    Bulk provisions Active Directory user accounts from a CSV file.

.DESCRIPTION
    New-BulkADUsers.ps1 reads a structured CSV file and creates AD user accounts
    using New-ADUser. Each user is placed into the appropriate Organizational Unit
    based on their department, assigned a secure temporary password, and enabled
    upon creation. Results are logged to a timestamped CSV report.

.PARAMETER CSVPath
    Path to the input CSV file. Defaults to .\SampleUsers.csv

.PARAMETER LogPath
    Path for the output results log. Defaults to .\BulkADUsers_Log_<timestamp>.csv

.PARAMETER DefaultPassword
    Temporary password assigned to all new accounts. Users will be forced to
    change it at next logon. Defaults to 'Welcome1!'

.EXAMPLE
    .\New-BulkADUsers.ps1
    .\New-BulkADUsers.ps1 -CSVPath "C:\Imports\NewHires.csv" -LogPath "C:\Logs\Results.csv"

.NOTES
    Author      : Elazar Ferrer
    Environment : Windows Server 2019, Active Directory Domain Services
    Requires    : ActiveDirectory PowerShell module (RSAT), Domain Admin or
                  delegated account creation rights
    Version     : 1.0
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$CSVPath = ".\SampleUsers.csv",

    [Parameter()]
    [string]$LogPath = ".\BulkADUsers_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",

    [Parameter()]
    [string]$DefaultPassword = 'Welcome1!'
)

#region --- Prerequisites ---

# Verify the ActiveDirectory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT tools and try again."
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop

# Verify the CSV exists
if (-not (Test-Path $CSVPath)) {
    Write-Error "CSV file not found at path: $CSVPath"
    exit 1
}

#endregion

#region --- Load and Validate CSV ---

$users = Import-Csv -Path $CSVPath

# Validate required columns
$requiredColumns = @('FirstName','LastName','Username','Department','OU','Email','Title')
$csvColumns = $users[0].PSObject.Properties.Name

foreach ($col in $requiredColumns) {
    if ($col -notin $csvColumns) {
        Write-Error "CSV is missing required column: '$col'"
        exit 1
    }
}

Write-Host "`n[INFO] Loaded $($users.Count) users from $CSVPath" -ForegroundColor Cyan

#endregion

#region --- Provision Users ---

$results = @()
$securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$created = 0
$skipped = 0
$failed  = 0

foreach ($user in $users) {

    $displayName = "$($user.FirstName) $($user.LastName)"
    $status      = $null
    $notes       = $null

    # Check if user already exists
    if (Get-ADUser -Filter { SamAccountName -eq $user.Username } -ErrorAction SilentlyContinue) {
        Write-Warning "SKIP  | $($user.Username) already exists in AD."
        $status = 'Skipped'
        $notes  = 'Account already exists'
        $skipped++
    }
    else {
        try {
            $newUserParams = @{
                SamAccountName        = $user.Username
                UserPrincipalName     = $user.Email
                GivenName             = $user.FirstName
                Surname               = $user.LastName
                DisplayName           = $displayName
                Name                  = $displayName
                Title                 = $user.Title
                Department            = $user.Department
                EmailAddress          = $user.Email
                Path                  = $user.OU
                AccountPassword       = $securePassword
                Enabled               = $true
                ChangePasswordAtLogon = $true
            }

            if ($PSCmdlet.ShouldProcess($user.Username, "Create AD User")) {
                New-ADUser @newUserParams -ErrorAction Stop
                Write-Host "OK    | Created: $displayName ($($user.Username)) -> $($user.OU)" -ForegroundColor Green
                $status = 'Created'
                $notes  = "Placed in $($user.OU)"
                $created++
            }
        }
        catch {
            Write-Warning "FAIL  | $($user.Username): $($_.Exception.Message)"
            $status = 'Failed'
            $notes  = $_.Exception.Message
            $failed++
        }
    }

    $results += [PSCustomObject]@{
        Timestamp   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Username    = $user.Username
        DisplayName = $displayName
        Department  = $user.Department
        OU          = $user.OU
        Email       = $user.Email
        Status      = $status
        Notes       = $notes
    }
}

#endregion

#region --- Export Results Log ---

$results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8

Write-Host "`n--- Provisioning Summary ---" -ForegroundColor Yellow
Write-Host "  Created : $created" -ForegroundColor Green
Write-Host "  Skipped : $skipped" -ForegroundColor Yellow
Write-Host "  Failed  : $failed"  -ForegroundColor Red
Write-Host "  Log     : $LogPath" -ForegroundColor Cyan
Write-Host ""

#endregion
