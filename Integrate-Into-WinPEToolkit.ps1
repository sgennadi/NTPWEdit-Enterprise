<#
.SYNOPSIS
    Installs NTPWEdit Enterprise scripts and architecture-specific binaries into a WinPE Toolkit folder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ToolkitPath,

    [string]$ReleaseDirectory = "$env:USERPROFILE\Downloads\NTPWEdit-EXE",
    [string]$X64Gui,
    [string]$X64Cli,
    [string]$X86Gui,
    [string]$X86Cli,
    [string]$Arm64Gui,
    [string]$Arm64Cli,
    [switch]$ScriptsOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Resolve-OptionalFile {
    param([string]$ExplicitPath,[string[]]$Candidates)
    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) { throw "File was not found: $ExplicitPath" }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

function Get-PeMachine {
    param([Parameter(Mandatory=$true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $reader = New-Object IO.BinaryReader($stream)
        $stream.Position = 0x3c
        $offset = $reader.ReadInt32()
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Invalid PE signature: $Path" }
        switch ($reader.ReadUInt16()) {
            0x014c { 'x86' }
            0x8664 { 'amd64' }
            0xaa64 { 'arm64' }
            default { 'unknown' }
        }
    }
    finally { $stream.Dispose() }
}

function Copy-ArchitectureTools {
    param(
        [Parameter(Mandatory=$true)][string]$Architecture,
        [string]$Gui,
        [string]$Cli,
        [Parameter(Mandatory=$true)][string]$ExpectedMachine,
        [Parameter(Mandatory=$true)][string]$GuiName,
        [Parameter(Mandatory=$true)][string]$DestinationRoot
    )
    if (-not $Gui -and -not $Cli) { return $false }
    if (-not $Gui -or -not $Cli) { throw "Both GUI and CLI files are required for $Architecture." }
    if ((Get-PeMachine -Path $Gui) -ne $ExpectedMachine) { throw "$Gui is not $ExpectedMachine." }
    if ((Get-PeMachine -Path $Cli) -ne $ExpectedMachine) { throw "$Cli is not $ExpectedMachine." }

    $destination = Join-Path $DestinationRoot $Architecture
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath $Gui -Destination (Join-Path $destination $GuiName) -Force
    Copy-Item -LiteralPath $Cli -Destination (Join-Path $destination 'ntpwcli.exe') -Force
    return $true
}

$release = [Environment]::ExpandEnvironmentVariables($ReleaseDirectory)
$x64GuiResolved = Resolve-OptionalFile -ExplicitPath $X64Gui -Candidates @(
    (Join-Path $release 'amd64\ntpwedit64.exe'),
    (Join-Path $release 'ntpwedit64.exe')
)
$x64CliResolved = Resolve-OptionalFile -ExplicitPath $X64Cli -Candidates @(
    (Join-Path $release 'amd64\ntpwcli.exe'),
    (Join-Path $release 'ntpwcli.exe'),
    (Join-Path $release 'ntpwcli64.exe')
)
$x86GuiResolved = Resolve-OptionalFile -ExplicitPath $X86Gui -Candidates @(
    (Join-Path $release 'x86\ntpwedit.exe'),
    (Join-Path $release 'ntpwedit.exe')
)
$x86CliResolved = Resolve-OptionalFile -ExplicitPath $X86Cli -Candidates @(
    (Join-Path $release 'x86\ntpwcli.exe'),
    (Join-Path $release 'ntpwcli32.exe')
)
$arm64GuiResolved = Resolve-OptionalFile -ExplicitPath $Arm64Gui -Candidates @(
    (Join-Path $release 'arm64\ntpweditarm64.exe'),
    (Join-Path $release 'ntpweditarm64.exe')
)
$arm64CliResolved = Resolve-OptionalFile -ExplicitPath $Arm64Cli -Candidates @(
    (Join-Path $release 'arm64\ntpwcli.exe'),
    (Join-Path $release 'ntpwcliarm64.exe')
)

$target = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($ToolkitPath))
New-Item -ItemType Directory -Path $target -Force | Out-Null
$winpeSource = Join-Path $PSScriptRoot 'WinPE'
if (-not (Test-Path -LiteralPath $winpeSource -PathType Container)) { throw "WinPE source folder was not found: $winpeSource" }

foreach ($file in @('Find-WindowsInstallations.ps1','Invoke-NTPWEditEnterprise.ps1','Start-PasswordReset.cmd','README_RU.txt')) {
    $source = Join-Path $winpeSource $file
    if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination (Join-Path $target $file) -Force }
}
$moduleSource = Join-Path $winpeSource 'Modules\PasswordReset.ps1'
$moduleDestination = Join-Path $target 'Modules\PasswordReset.ps1'
New-Item -ItemType Directory -Path (Split-Path -Parent $moduleDestination) -Force | Out-Null
Copy-Item -LiteralPath $moduleSource -Destination $moduleDestination -Force

$toolsRoot = Join-Path $target 'Tools\PasswordReset'
New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null
$installed = [System.Collections.Generic.List[string]]::new()
if (-not $ScriptsOnly) {
    if (Copy-ArchitectureTools -Architecture 'amd64' -Gui $x64GuiResolved -Cli $x64CliResolved -ExpectedMachine 'amd64' -GuiName 'ntpwedit64.exe' -DestinationRoot $toolsRoot) { $installed.Add('amd64') | Out-Null }
    if (Copy-ArchitectureTools -Architecture 'x86' -Gui $x86GuiResolved -Cli $x86CliResolved -ExpectedMachine 'x86' -GuiName 'ntpwedit.exe' -DestinationRoot $toolsRoot) { $installed.Add('x86') | Out-Null }
    if (Copy-ArchitectureTools -Architecture 'arm64' -Gui $arm64GuiResolved -Cli $arm64CliResolved -ExpectedMachine 'arm64' -GuiName 'ntpweditarm64.exe' -DestinationRoot $toolsRoot) { $installed.Add('arm64') | Out-Null }
    if ($installed.Count -eq 0) {
        throw "No complete GUI/CLI architecture pair was found under: $release"
    }
}

$rootLauncher = Join-Path $target 'PasswordReset.cmd'
@'
@echo off
call "%~dp0Start-PasswordReset.cmd"
exit /b %ERRORLEVEL%
'@ | Set-Content -LiteralPath $rootLauncher -Encoding ASCII

$snippet = Join-Path $target 'PasswordReset-Menu-Snippet.txt'
@'
REM Add this item to an existing CMD menu:
REM   call "%~dp0PasswordReset.cmd"

# PowerShell module use:
Import-Module "$PSScriptRoot\Modules\PasswordReset.ps1" -Force
Start-NTPWEditPasswordReset -ToolkitRoot $PSScriptRoot
'@ | Set-Content -LiteralPath $snippet -Encoding UTF8

Write-Host ''
Write-Host "NTPWEdit Enterprise integrated into: $target" -ForegroundColor Green
if ($ScriptsOnly) {
    Write-Host 'Scripts-only mode: no EXE files were copied.' -ForegroundColor Yellow
} else {
    Write-Host ('Architectures installed: {0}' -f ($installed.ToArray() -join ', ')) -ForegroundColor Green
}
Write-Host "Launcher: $rootLauncher"
