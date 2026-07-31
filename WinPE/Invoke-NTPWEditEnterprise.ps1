<#
.SYNOPSIS
    WinPE operator interface for NTPWEdit Enterprise 1.0.0.
#>
[CmdletBinding()]
param(
    [ValidateSet('Menu','Discover','List','Json','Gui')]
    [string]$Mode = 'Menu',
    [string]$SamPath,
    [string]$JsonPath,
    [int]$Rid,
    [string]$UserName,
    [switch]$NoAutomaticBackup
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Finder = Join-Path $ScriptRoot 'Find-WindowsInstallations.ps1'

function Get-ArchitectureFolder {
    $architecture = [string]$env:PROCESSOR_ARCHITECTURE
    switch -Regex ($architecture.ToUpperInvariant()) {
        'ARM64' { return 'arm64' }
        'X86' { return 'x86' }
        default { return 'amd64' }
    }
}

function Resolve-ToolFile {
    param([Parameter(Mandatory=$true)][string[]]$Names)
    $arch = Get-ArchitectureFolder
    $roots = @(
        (Join-Path $ScriptRoot "Tools\PasswordReset\$arch"),
        (Join-Path $ScriptRoot 'Tools\PasswordReset'),
        $ScriptRoot
    )
    foreach ($root in $roots) {
        foreach ($name in $Names) {
            $candidate = Join-Path $root $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    return $null
}

$ArchitectureFolder = Get-ArchitectureFolder
$CliNames = switch ($ArchitectureFolder) {
    'arm64' { @('ntpwcliarm64.exe','ntpwcli.exe') }
    'x86' { @('ntpwcli32.exe','ntpwcli.exe') }
    default { @('ntpwcli.exe','ntpwcli64.exe') }
}
$Cli = Resolve-ToolFile -Names $CliNames
$GuiNames = switch ($ArchitectureFolder) {
    'arm64' { @('ntpweditarm64.exe') }
    'x86' { @('ntpwedit.exe') }
    default { @('ntpwedit64.exe') }
}
$Gui = Resolve-ToolFile -Names $GuiNames
if (-not $Cli) { throw 'ntpwcli.exe was not found under Tools\PasswordReset\<architecture>.' }
if (-not (Test-Path -LiteralPath $Finder -PathType Leaf)) { throw "Windows discovery script was not found: $Finder" }

function Invoke-Cli {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$AllowNonZero
    )
    & $Cli @Arguments
    $code = $LASTEXITCODE
    if (-not $AllowNonZero -and $code -ne 0) {
        throw "ntpwcli.exe returned exit code $code."
    }
    $script:LastCliExitCode = $code
}

function Start-NtpwGui {
    param(
        [Parameter(Mandatory=$true)]$Installation,
        $User
    )
    if (-not $Gui) { throw 'The GUI executable for this architecture was not found.' }
    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('/sam') | Out-Null
    $arguments.Add(('"{0}"' -f [string]$Installation.SamPath)) | Out-Null
    if ($User) {
        $arguments.Add('/rid') | Out-Null
        $arguments.Add([string]$User.rid) | Out-Null
    } elseif ($Rid -gt 0) {
        $arguments.Add('/rid') | Out-Null
        $arguments.Add([string]$Rid) | Out-Null
    } elseif ($UserName) {
        $arguments.Add('/user') | Out-Null
        $arguments.Add(('"{0}"' -f $UserName)) | Out-Null
    }
    $arguments.Add('/open') | Out-Null
    Start-Process -FilePath $Gui -ArgumentList $arguments.ToArray() -Wait
}

function Get-Installations {
    return @(& $Finder)
}

function Unlock-BitLockerInteractive {
    if (-not (Get-Command manage-bde.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'manage-bde.exe is not available in this WinPE image.' -ForegroundColor Red
        return $false
    }
    $letter = (Read-Host 'Drive letter to unlock (example D)').Trim().TrimEnd(':').ToUpperInvariant()
    if ($letter -notmatch '^[A-Z]$') {
        Write-Host 'Invalid drive letter.' -ForegroundColor Red
        return $false
    }
    $secure = Read-Host 'Enter the 48-digit BitLocker recovery password' -AsSecureString
    $plain = $null
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if ($plain -notmatch '^\d{6}(?:-\d{6}){7}$') {
            Write-Host 'Recovery password format is invalid.' -ForegroundColor Red
            return $false
        }
        & manage-bde.exe -unlock "${letter}:" -RecoveryPassword $plain
        if ($LASTEXITCODE -ne 0) {
            Write-Host "BitLocker unlock failed with exit code $LASTEXITCODE." -ForegroundColor Red
            return $false
        }
        Write-Host "${letter}: unlocked." -ForegroundColor Green
        return $true
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        $plain = $null
        $secure = $null
    }
}

function Select-WindowsInstallation {
    while ($true) {
        $items = @(Get-Installations)
        if ($SamPath) {
            $match = $items | Where-Object { $_.SamPath -ieq $SamPath } | Select-Object -First 1
            if ($match) { return $match }
            if (Test-Path -LiteralPath $SamPath -PathType Leaf) {
                return [pscustomobject]@{
                    DriveLetter = (Split-Path -Qualifier $SamPath).TrimEnd([char[]]':\')
                    WindowsPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $SamPath))
                    SamPath = $SamPath
                    ProductName = 'Selected Windows installation'
                    DisplayVersion = $null
                    Build = $null
                    BitLocker = 'Unknown'
                }
            }
            throw "SAM file was not found: $SamPath"
        }

        Clear-Host
        Write-Host '============================================================' -ForegroundColor Cyan
        Write-Host ' NTPWEdit Enterprise 1.0.0 - Windows selection' -ForegroundColor Cyan
        Write-Host '============================================================' -ForegroundColor Cyan
        if ($items.Count -gt 0) {
            for ($i = 0; $i -lt $items.Count; $i++) {
                $item = $items[$i]
                $versionParts = @([string]$item.DisplayVersion, [string]$item.Build) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                $version = $versionParts -join ' / '
                Write-Host ('[{0}] {1}:  {2}  {3}  BitLocker={4}' -f ($i + 1), $item.DriveLetter, $item.ProductName, $version, $item.BitLocker)
                Write-Host ('    {0}' -f $item.WindowsPath) -ForegroundColor DarkGray
            }
        } else {
            Write-Host 'No readable offline Windows installation was detected.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host 'U - Unlock a BitLocker volume'
        Write-Host 'R - Rescan'
        Write-Host '0 - Exit'
        $choice = (Read-Host 'Selection').Trim()
        if ($choice -eq '0') { return $null }
        if ($choice -match '^[Uu]$') { [void](Unlock-BitLockerInteractive); continue }
        if ($choice -match '^[Rr]$') { continue }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $items.Count) {
            return $items[$number - 1]
        }
    }
}

function Get-LogRoot {
    param([Parameter(Mandatory=$true)]$Installation)
    $drive = ([string]$Installation.DriveLetter).TrimEnd(':')
    $root = "${drive}:\RecoveryLogs\NTPWEdit"
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

function Write-AuditEntry {
    param(
        [Parameter(Mandatory=$true)]$Installation,
        [Parameter(Mandatory=$true)][string]$Message
    )
    try {
        $root = Get-LogRoot -Installation $Installation
        $line = '{0}  {1}  {2}' -f ([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')), $env:COMPUTERNAME, $Message
        Add-Content -LiteralPath (Join-Path $root 'NTPWEdit-Audit.log') -Value $line -Encoding UTF8
    } catch { }
}

function New-SafetyBackup {
    param(
        [Parameter(Mandatory=$true)]$Installation,
        [Parameter(Mandatory=$true)][string]$Reason
    )
    $root = Get-LogRoot -Installation $Installation
    $safeReason = ($Reason -replace '[^A-Za-z0-9_-]', '_')
    $folder = Join-Path $root ('Backups\{0}_{1}' -f ([DateTime]::Now.ToString('yyyyMMdd_HHmmss_fff')), $safeReason)
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Invoke-Cli -Arguments @('/sam',[string]$Installation.SamPath,'/backup',$folder) | Out-Null
    Write-AuditEntry -Installation $Installation -Message "Backup created: $folder; reason=$Reason"
    return $folder
}

function Get-UsersFromSam {
    param([Parameter(Mandatory=$true)]$Installation)
    $temporary = Join-Path $env:TEMP ('ntpw-users-{0}.json' -f [Guid]::NewGuid().ToString('N'))
    try {
        Invoke-Cli -Arguments @('/sam',[string]$Installation.SamPath,'/list','/format','json','/output',$temporary) | Out-Null
        $document = Get-Content -LiteralPath $temporary -Raw | ConvertFrom-Json
        return @($document.users)
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

function Export-UsersJson {
    param([Parameter(Mandatory=$true)]$Installation)
    $root = Get-LogRoot -Installation $Installation
    $path = Join-Path $root ('Users_{0}.json' -f [DateTime]::Now.ToString('yyyyMMdd_HHmmss_fff'))
    Invoke-Cli -Arguments @('/sam',[string]$Installation.SamPath,'/list','/format','json','/output',$path) | Out-Null
    Write-AuditEntry -Installation $Installation -Message "User inventory exported: $path"
    Write-Host "Saved: $path" -ForegroundColor Green
}

function Invoke-AccountMutation {
    param(
        [Parameter(Mandatory=$true)]$Installation,
        [Parameter(Mandatory=$true)]$User,
        [Parameter(Mandatory=$true)][string[]]$ActionArguments,
        [Parameter(Mandatory=$true)][string]$ActionName
    )
    if (-not $NoAutomaticBackup) {
        $backup = New-SafetyBackup -Installation $Installation -Reason ("RID{0}_{1}" -f $User.rid, $ActionName)
        Write-Host "Safety backup: $backup" -ForegroundColor DarkGray
    }
    $arguments = @('/sam',[string]$Installation.SamPath,'/rid',[string]$User.rid) + $ActionArguments + @('--confirm','WRITE')
    Invoke-Cli -Arguments $arguments | Out-Null
    Write-AuditEntry -Installation $Installation -Message "Action=$ActionName; RID=$($User.rid); User=$($User.name); Result=Success"
    Write-Host "Completed: $ActionName for $($User.name)." -ForegroundColor Green
}

function Restore-BackupInteractive {
    param([Parameter(Mandatory=$true)]$Installation)
    $root = Join-Path (Get-LogRoot -Installation $Installation) 'Backups'
    $folders = @()
    if (Test-Path -LiteralPath $root) {
        $folders = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object LastWriteTime -Descending)
    }
    if ($folders.Count -eq 0) {
        Write-Host 'No backup folders were found.' -ForegroundColor Yellow
        return
    }
    for ($i = 0; $i -lt $folders.Count; $i++) {
        Write-Host ('[{0}] {1}  {2}' -f ($i + 1), $folders[$i].Name, $folders[$i].LastWriteTime)
    }
    $choice = Read-Host 'Backup number, or 0 to cancel'
    $number = 0
    if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $folders.Count) { return }
    $confirmation = Read-Host 'Type RESTORE to overwrite the offline registry hives'
    if ($confirmation -cne 'RESTORE') {
        Write-Host 'Restore cancelled.' -ForegroundColor Yellow
        return
    }
    Invoke-Cli -Arguments @('/sam',[string]$Installation.SamPath,'/restore',$folders[$number - 1].FullName,'--confirm','RESTORE') | Out-Null
    Write-AuditEntry -Installation $Installation -Message "Registry hives restored from $($folders[$number - 1].FullName)"
    Write-Host 'Restore completed.' -ForegroundColor Green
}

function Select-User {
    param([Parameter(Mandatory=$true)]$Installation)
    $users = @(Get-UsersFromSam -Installation $Installation)
    if ($users.Count -eq 0) { throw 'No local users were returned by ntpwcli.exe.' }
    Write-Host ''
    Write-Host ('Local users in {0}' -f $Installation.SamPath) -ForegroundColor Cyan
    Write-Host ('{0,-4} {1,-8} {2,-22} {3,-9} {4,-8} {5,-7} {6}' -f '#','RID','STATE','DISABLED','LOCKED','FAILED','NAME')
    for ($i = 0; $i -lt $users.Count; $i++) {
        $user = $users[$i]
        Write-Host ('{0,-4} {1,-8} {2,-22} {3,-9} {4,-8} {5,-7} {6}' -f ($i + 1), $user.rid, $user.state, $user.disabled, $user.locked, $user.failedCount, $user.name)
    }
    $choice = Read-Host 'User number, R to refresh, W to change Windows, or 0 to exit'
    if ($choice -match '^[Rr]$') { return '__REFRESH__' }
    if ($choice -match '^[Ww]$') { return '__WINDOWS__' }
    if ($choice -eq '0') { return $null }
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $users.Count) {
        return $users[$number - 1]
    }
    return '__REFRESH__'
}

function Show-ActionMenu {
    param([Parameter(Mandatory=$true)]$User)
    Write-Host ''
    Write-Host ('Selected: {0}  RID={1}  State={2}' -f $User.name, $User.rid, $User.state) -ForegroundColor Cyan
    Write-Host '1  Open original NTPWEdit GUI'
    Write-Host '2  Unlock account only'
    Write-Host '3  Enable account only'
    Write-Host '4  Unlock and enable account'
    Write-Host '5  Disable account'
    Write-Host '6  Set a new password (hidden input)'
    Write-Host '7  Unlock + enable + set password'
    Write-Host '8  Clear password'
    Write-Host '9  Create registry-hive backup now'
    Write-Host '10 Restore a previous backup'
    Write-Host '11 Export all local users to JSON'
    Write-Host 'R  Refresh user status'
    Write-Host 'B  Back to Windows selection'
    Write-Host '0  Exit'
    return (Read-Host 'Action').Trim()
}

if ($Mode -eq 'Discover') {
    & $Finder -AsJson
    return
}

$installation = Select-WindowsInstallation
if (-not $installation) { return }

if ($Mode -eq 'List') {
    Invoke-Cli -Arguments @('/sam',[string]$installation.SamPath,'/list')
    return
}
if ($Mode -eq 'Json') {
    if (-not $JsonPath) { $JsonPath = Join-Path (Get-LogRoot -Installation $installation) 'Users.json' }
    Invoke-Cli -Arguments @('/sam',[string]$installation.SamPath,'/list','/format','json','/output',$JsonPath) | Out-Null
    Write-Host "Saved: $JsonPath" -ForegroundColor Green
    return
}
if ($Mode -eq 'Gui') {
    Write-Host "Selected SAM: $($installation.SamPath)" -ForegroundColor Cyan
    Start-NtpwGui -Installation $installation
    return
}

:WindowsLoop while ($true) {
    if (-not $installation) {
        $installation = Select-WindowsInstallation
        if (-not $installation) { break }
    }

    $selectedUser = Select-User -Installation $installation
    if ($null -eq $selectedUser) { break }
    if ($selectedUser -eq '__WINDOWS__') { $installation = $null; continue WindowsLoop }
    if ($selectedUser -eq '__REFRESH__') { continue WindowsLoop }

    :ActionLoop while ($true) {
        $action = Show-ActionMenu -User $selectedUser
        try {
            switch ($action.ToUpperInvariant()) {
                '1' {
                    Start-NtpwGui -Installation $installation -User $selectedUser
                }
                '2' { Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/unlock') -ActionName 'Unlock'; break ActionLoop }
                '3' { Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/enable') -ActionName 'Enable'; break ActionLoop }
                '4' { Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/unlock-enable') -ActionName 'UnlockEnable'; break ActionLoop }
                '5' { Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/disable') -ActionName 'Disable'; break ActionLoop }
                '6' { Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/password-prompt') -ActionName 'SetPassword'; break ActionLoop }
                '7' { Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/unlock-enable','/password-prompt') -ActionName 'UnlockEnableSetPassword'; break ActionLoop }
                '8' {
                    $confirm = Read-Host 'Type CLEAR to remove the local password'
                    if ($confirm -ceq 'CLEAR') {
                        Invoke-AccountMutation -Installation $installation -User $selectedUser -ActionArguments @('/password-blank') -ActionName 'ClearPassword'
                        break ActionLoop
                    }
                }
                '9' {
                    $backup = New-SafetyBackup -Installation $installation -Reason 'Manual'
                    Write-Host "Backup created: $backup" -ForegroundColor Green
                }
                '10' { Restore-BackupInteractive -Installation $installation; break ActionLoop }
                '11' { Export-UsersJson -Installation $installation }
                'R' { break ActionLoop }
                'B' { $installation = $null; continue WindowsLoop }
                '0' { break WindowsLoop }
                default { Write-Host 'Unknown selection.' -ForegroundColor Yellow }
            }
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-AuditEntry -Installation $installation -Message "Action failed for RID=$($selectedUser.rid): $($_.Exception.Message)"
            Read-Host 'Press Enter to continue' | Out-Null
        }
    }
}
