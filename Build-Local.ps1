<#
.SYNOPSIS
    Builds GUI and ntpwcli locally with an installed Visual Studio 2022 C++ toolchain.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = "$env:USERPROFILE\Documents\GitHub\NTPWEdit-Mirror",
    [ValidateSet('amd64','x86','arm64','all')]
    [string]$Architecture = 'all',
    [string]$OutputDirectory = "$env:USERPROFILE\Downloads\NTPWEdit-LocalBuild",
    [string]$BuildRoot = "$env:TEMP\NTPWEdit-Enterprise-Build",
    [switch]$Clean
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-PeMachine([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $reader = New-Object IO.BinaryReader($stream)
        $stream.Position = 0x3c
        $offset = $reader.ReadInt32()
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Invalid PE file: $Path" }
        switch ($reader.ReadUInt16()) {
            0x014c { 'x86' }
            0x8664 { 'amd64' }
            0xaa64 { 'arm64' }
            default { 'unknown' }
        }
    } finally { $stream.Dispose() }
}

if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) {
    throw 'cmake.exe was not found. Install Visual Studio 2022 Build Tools with Desktop development with C++ and CMake.'
}
$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$source = Join-Path $repo 'src'
if (-not (Test-Path -LiteralPath (Join-Path $source 'ntpwcli.c') -PathType Leaf)) {
    throw 'Enterprise overlay is not applied. Run Apply-EnterpriseCLI.ps1 first.'
}
$output = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($OutputDirectory))
$buildRootResolved = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($BuildRoot))
New-Item -ItemType Directory -Path $output -Force | Out-Null
New-Item -ItemType Directory -Path $buildRootResolved -Force | Out-Null

$targets = @(
    [pscustomobject]@{ Name='amd64'; Generator='x64'; Gui='ntpwedit64.exe' },
    [pscustomobject]@{ Name='x86'; Generator='Win32'; Gui='ntpwedit.exe' },
    [pscustomobject]@{ Name='arm64'; Generator='ARM64'; Gui='ntpweditarm64.exe' }
)
if ($Architecture -ne 'all') { $targets = @($targets | Where-Object Name -eq $Architecture) }

foreach ($target in $targets) {
    Write-Host "`n==> Building $($target.Name)" -ForegroundColor Cyan
    $build = Join-Path $buildRootResolved ("build-{0}" -f $target.Name)
    # Always remove the architecture build tree. This prevents old CMake
    # cache/compiler settings from previous Enterprise versions from affecting
    # the current deterministic build. -Clean is retained for compatibility.
    if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
    & cmake.exe -S $source -B $build -A $target.Generator -DNTPWEDIT_BUILD_GUI=ON -DNTPWEDIT_BUILD_CLI=ON -DNTPWEDIT_ENABLE_TESTS=ON
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed for $($target.Name)." }
    & cmake.exe --build $build --config Release --parallel
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed for $($target.Name)." }

    $gui = Get-ChildItem -LiteralPath $build -Recurse -File -Filter $target.Gui | Select-Object -First 1
    $cli = Get-ChildItem -LiteralPath $build -Recurse -File -Filter ntpwcli.exe | Select-Object -First 1
    if (-not $gui -or -not $cli) { throw "Expected binaries were not produced for $($target.Name)." }
    if ((Get-PeMachine $gui.FullName) -ne $target.Name) { throw "GUI architecture verification failed for $($target.Name)." }
    if ((Get-PeMachine $cli.FullName) -ne $target.Name) { throw "CLI architecture verification failed for $($target.Name)." }

    $destination = Join-Path $output $target.Name
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item $gui.FullName (Join-Path $destination $target.Gui) -Force
    Copy-Item $cli.FullName (Join-Path $destination 'ntpwcli.exe') -Force

    if ($target.Name -ne 'arm64') {
        $cliPath = Join-Path $destination 'ntpwcli.exe'
        $versionOutput = @(& $cliPath /version 2>&1)
        $versionExitCode = $LASTEXITCODE
        $versionOutput | ForEach-Object { Write-Host ([string]$_) }
        if ($versionExitCode -ne 0) { throw "ntpwcli /version smoke test failed for $($target.Name), exit $versionExitCode." }

        $helpOutput = @(& $cliPath /? 2>&1)
        $helpExitCode = $LASTEXITCODE
        if ($helpExitCode -ne 0) { throw "ntpwcli /? smoke test failed for $($target.Name), exit $helpExitCode." }
        if (($helpOutput -join "`n") -notmatch 'NTPWEdit Enterprise CLI') {
            throw "ntpwcli /? returned unexpected output for $($target.Name)."
        }

        $discoveryJson = Join-Path $destination 'discovery-smoke.json'
        $discoveryOutput = @(& $cliPath /discover /format json /output $discoveryJson 2>&1)
        $discoveryExitCode = $LASTEXITCODE
        $discoveryOutput | ForEach-Object { Write-Host ([string]$_) }
        if ($discoveryExitCode -ne 0) { throw "ntpwcli discovery smoke test failed for $($target.Name), exit $discoveryExitCode." }
        $document = Get-Content -LiteralPath $discoveryJson -Raw | ConvertFrom-Json
        if ($document.tool -ne 'ntpwcli' -or $document.schemaVersion -ne 1) {
            throw "ntpwcli discovery JSON validation failed for $($target.Name)."
        }
        Remove-Item -LiteralPath $discoveryJson -Force
    }
}

Write-Host "`nLocal build completed: $output" -ForegroundColor Green
exit 0
