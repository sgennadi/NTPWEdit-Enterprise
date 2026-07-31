[CmdletBinding()]
param(
    [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
    [string]$BinaryDirectory
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-Contains {
    param([string]$Path,[string[]]$Tokens)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    $text = Get-Content -LiteralPath $Path -Raw
    foreach ($token in $Tokens) {
        if (-not $text.Contains($token)) { throw "Missing token '$token' in $Path" }
    }
}

$src = Join-Path $RepositoryPath 'src'
Assert-Contains -Path (Join-Path $src 'CMakeLists.txt') -Tokens @(
    'add_executable(ntpwcli',
    'ntpweditarm64',
    'NTPWEDIT_BUILD_CLI',
    'guiargs.c',
    'shell32', 'comdlg32', 'comctl32'
)
$cmakeText = Get-Content -LiteralPath (Join-Path $src 'CMakeLists.txt') -Raw
if ($cmakeText.Contains('WIN32_LEAN_AND_MEAN')) { throw 'WIN32_LEAN_AND_MEAN remains in CMakeLists.txt.' }
Assert-Contains -Path (Join-Path $src 'main.c') -Tokens @('#include <commdlg.h>', '#include <shellapi.h>')
Assert-Contains -Path (Join-Path $src 'version.c') -Tokens @('NTPWEdit Enterprise 1.0.0')
Assert-Contains -Path (Join-Path $src 'libdlg\unicode.h') -Tokens @('#include <shellapi.h>')
Assert-Contains -Path (Join-Path $src 'dlgabout.c') -Tokens @('#include <shellapi.h>')
Assert-Contains -Path (Join-Path $src 'message.c') -Tokens @('#include <stdlib.h>', '#include <string.h>')

Assert-Contains -Path (Join-Path $src 'guiargs.c') -Tokens @(
    'GuiArgsInitialize', 'GuiArgsSamPath', 'GuiArgsShouldAutoOpen',
    'GuiArgsSelectUser', 'CommandLineToArgvW', 'LVM_GETITEMW', 'LVM_GETITEMTEXTW'
)
$guiArgsSource = Get-Content -LiteralPath (Join-Path $src 'guiargs.c') -Raw
if ($guiArgsSource -match 'ListView_GetItemW\s*\(|ListView_GetItemTextW\s*\(') {
    throw 'Unsupported ListView_*W helper calls remain in guiargs.c.'
}

Assert-Contains -Path (Join-Path $src 'cli.c') -Tokens @(
    '/discover', '/list', '/status', '/backup', '/restore', '/unlock',
    '/enable', '/disable', '/unlock-enable', '/password-prompt',
    '/password-stdin', '/password-file', '/password-blank'
)
Assert-Contains -Path (Join-Path $src 'libntpw\ntpw.h') -Tokens @(
    'struct account_status', 'get_account_status', 'clear_account_lockout', 'set_account_enabled'
)
Assert-Contains -Path (Join-Path $src 'libntpw\ntpw.c') -Tokens @(
    'NTPWEDIT_ENTERPRISE_ACCOUNT_STATUS_BEGIN',
    'locked_by_count',
    'enterprise_store_user_f'
)

$main = Get-Content -LiteralPath (Join-Path $src 'main.c') -Raw
if ($main -match 'cli_should_run|app_main\s*\(') { throw 'Legacy hybrid GUI/CLI code remains in main.c.' }
if ($main -notmatch 'int\s+main\s*\(\s*void\s*\)') { throw 'GUI main(void) was not found.' }
foreach ($token in @('#include "guiargs.h"','GuiArgsInitialize();','GuiArgsShouldAutoOpen()','GuiArgsSelectUser(')) {
    if (-not $main.Contains($token)) { throw "Missing GUI command-line integration token: $token" }
}

$powerShellFiles = Get-ChildItem -LiteralPath $RepositoryPath -Recurse -File -Filter *.ps1 | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]'
}
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) {
        $errors | Format-List
        throw "PowerShell syntax error: $($file.FullName)"
    }
}

foreach ($schema in Get-ChildItem (Join-Path $RepositoryPath 'schemas') -Filter *.json -File -ErrorAction SilentlyContinue) {
    [void](Get-Content -LiteralPath $schema.FullName -Raw | ConvertFrom-Json)
}

if ($BinaryDirectory) {
    $cli = Join-Path $BinaryDirectory 'ntpwcli.exe'
    if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) { throw "ntpwcli.exe was not found: $cli" }
    & $cli /version
    if ($LASTEXITCODE -ne 0) { throw "ntpwcli /version failed: $LASTEXITCODE" }
    $temporary = Join-Path $env:TEMP ('ntpwcli-test-{0}.json' -f [Guid]::NewGuid().ToString('N'))
    try {
        & $cli /discover /format json /output $temporary
        if ($LASTEXITCODE -ne 0) { throw "ntpwcli /discover failed: $LASTEXITCODE" }
        $document = Get-Content -LiteralPath $temporary -Raw | ConvertFrom-Json
        if ($document.tool -ne 'ntpwcli' -or $document.schemaVersion -ne 1) {
            throw 'Unexpected ntpwcli discovery JSON.'
        }
    }
    finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
}

Write-Host 'NTPWEdit Enterprise source contract validation passed.' -ForegroundColor Green
