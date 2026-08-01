[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$ExpectedVersion = '1.0.0'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Get-RelativeRepositoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$FullName
    )

    $relative = $FullName.Substring($Root.Length)
    $relative = $relative.TrimStart([char]92, [char]47)
    return $relative.Replace([char]47, [char]92)
}

function Remove-CSourceComments {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ''
    }

    # Strip comments with a small lexical scanner. A regular expression such as
    # //.* would also delete the // inside an https:// URL string and would make
    # a correct About dialog fail the metadata audit.
    $builder = New-Object System.Text.StringBuilder
    $state = 'code'
    $index = 0
    while ($index -lt $Text.Length) {
        $current = $Text[$index]
        $next = if (($index + 1) -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

        if ($state -eq 'code') {
            if ($current -eq '/' -and $next -eq '/') {
                $state = 'line-comment'
                $index += 2
                continue
            }
            if ($current -eq '/' -and $next -eq '*') {
                $state = 'block-comment'
                $index += 2
                continue
            }

            [void]$builder.Append($current)
            if ($current -eq '"') { $state = 'string' }
            elseif ($current -eq "'") { $state = 'character' }
            $index++
            continue
        }

        if ($state -eq 'string' -or $state -eq 'character') {
            [void]$builder.Append($current)
            if ($current -eq '\' -and ($index + 1) -lt $Text.Length) {
                [void]$builder.Append($next)
                $index += 2
                continue
            }
            if (($state -eq 'string' -and $current -eq '"') -or
                ($state -eq 'character' -and $current -eq "'")) {
                $state = 'code'
            }
            $index++
            continue
        }

        if ($state -eq 'line-comment') {
            if ($current -eq "`r" -or $current -eq "`n") {
                [void]$builder.Append($current)
                $state = 'code'
            }
            $index++
            continue
        }

        if ($state -eq 'block-comment') {
            if ($current -eq '*' -and $next -eq '/') {
                $state = 'code'
                $index += 2
                continue
            }
            if ($current -eq "`r" -or $current -eq "`n") {
                [void]$builder.Append($current)
            }
            $index++
            continue
        }
    }

    return $builder.ToString()
}

$root = (Resolve-Path -LiteralPath $RepositoryPath).Path

$required = @(
    'src\HISTORY.txt'
    'src\version.c'
    'src\dlgabout.c'
    'src\CMakeLists.txt'
    'src\cli.c'
    'README_ENTERPRISE_RU.txt'
    'LICENSE-ENTERPRISE-NOTICE.txt'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required metadata file is missing: $relative"
    }
}

$historyPath = Join-Path $root 'src\HISTORY.txt'
$versionPath = Join-Path $root 'src\version.c'
$aboutPath = Join-Path $root 'src\dlgabout.c'
$cliPath = Join-Path $root 'src\cli.c'

$history = Get-Content -LiteralPath $historyPath -Raw
$historyTokens = @(
    '===== NTPWEDIT ENTERPRISE HISTORY BEGIN ====='
    "Version $ExpectedVersion"
    'native ntpwcli.exe console application'
    'Upstream NTPWEdit history'
)

foreach ($token in $historyTokens) {
    if (-not $history.Contains($token)) {
        throw "src\HISTORY.txt is missing required text: $token"
    }
}

$versionText = Get-Content -LiteralPath $versionPath -Raw
if (-not $versionText.Contains("NTPWEdit Enterprise $ExpectedVersion")) {
    throw 'src\version.c has stale product version metadata.'
}
if (-not $versionText.Contains('AppAuthor = L"NTPWEdit Enterprise project"')) {
    throw 'src\version.c has stale visible AppAuthor metadata.'
}

$cliText = Get-Content -LiteralPath $cliPath -Raw
if (-not $cliText.Contains($ExpectedVersion)) {
    throw 'src\cli.c has stale CLI version metadata.'
}

$aboutText = Get-Content -LiteralPath $aboutPath -Raw
$aboutExecutableText = Remove-CSourceComments -Text $aboutText
$requiredAboutTokens = @(
    'About NTPWEdit Enterprise'
    'https://github.com/sgennadi/NTPWEdit-Enterprise'
    'Third-party notices: LICENSE-ENTERPRISE-NOTICE.txt'
    'ShellExecuteW'
    'ID_LABEL_PROJECT_URL'
)
foreach ($token in $requiredAboutTokens) {
    if (-not $aboutExecutableText.Contains($token)) {
        throw "src\dlgabout.c is missing required visible About text: $token"
    }
}

$obsoleteVisiblePatterns = @(
    'L"mailto:cdslow@mail\.ru"'
    'L"http://cdslow\.org\.ru/ntpwedit/"'
    'L"Copyright \(c\) Petter Nordahl-Hagen, pnh@pogostick\.net'
)
foreach ($pattern in $obsoleteVisiblePatterns) {
    if ($aboutExecutableText -match $pattern) {
        throw "Obsolete visible About metadata remains in src\dlgabout.c: $pattern"
    }
}

$versionExecutableText = Remove-CSourceComments -Text $versionText
if ($versionExecutableText -match 'AppAuthor\s*=\s*L"[^"]*(Vadim|cdslow|pogostick)') {
    throw 'Obsolete visible AppAuthor metadata remains in src\version.c.'
}


# Check every file that can contribute visible executable metadata. Legal and
# historical text outside executable strings is intentionally preserved.
$visibleMetadataFiles = @($versionPath, $aboutPath)
$visibleMetadataFiles += @(Get-ChildItem -LiteralPath (Join-Path $root 'src') -File -Filter 'resource*.rc' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$resDirectory = Join-Path $root 'src\res'
if (Test-Path -LiteralPath $resDirectory -PathType Container) {
    $visibleMetadataFiles += @(Get-ChildItem -LiteralPath $resDirectory -File -Filter '*.manifest' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
foreach ($metadataFile in ($visibleMetadataFiles | Select-Object -Unique)) {
    $metadataText = Get-Content -LiteralPath $metadataFile -Raw
    $metadataExecutable = Remove-CSourceComments -Text $metadataText
    if ($metadataExecutable -match 'NTPWEdit\s+0\.(?:7|70)(?![0-9])') {
        $relative = Get-RelativeRepositoryPath -Root $root -FullName $metadataFile
        throw "Old visible NTPWEdit version remains in $relative"
    }
    if ($metadataExecutable -match 'mailto:cdslow@mail\.ru|https?://cdslow\.org\.ru/ntpwedit/?|pnh@pogostick\.net') {
        $relative = Get-RelativeRepositoryPath -Root $root -FullName $metadataFile
        throw "Obsolete visible contact metadata remains in $relative"
    }
}

if ($aboutExecutableText -match 'ID_LABEL_MAIL|ID_LABEL_URL|NTReg_Proc') {
    throw 'src\dlgabout.c still contains legacy About control or callback identifiers.'
}

$extensions = @('.md', '.txt', '.c', '.h', '.ps1', '.cmd', '.json', '.yml', '.yaml')
$allTextFiles = Get-ChildItem -LiteralPath $root -Recurse -File -Force |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }

# Build known broken UTF-8 sequences from character codes so this script remains
# plain ASCII and works in Windows PowerShell 5.1.
$badMojibake = @()
$badMojibake += [string]([char]0x05D2) + [string]([char]0x20AC) + [string]([char]0x201D)
$badMojibake += [string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201D)
$badMojibake += [string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201C)
$badMojibake += [string]([char]0xFFFD)

foreach ($file in $allTextFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw

    foreach ($bad in $badMojibake) {
        if ($text.Contains($bad)) {
            $relative = Get-RelativeRepositoryPath -Root $root -FullName $file.FullName
            throw "Mojibake found in $relative"
        }
    }

    # Only reject old 3.x numbers when they are attached to the Enterprise
    # product name. Generic dependency/tool versions such as CMake 3.x are valid.
    if ($text -match '(?i)NTPWEdit(?:-|\s+)Enterprise[^\r\n]{0,80}(?<![0-9])3\.[0-9]+\.[0-9]+(?![0-9])') {
        $relative = Get-RelativeRepositoryPath -Root $root -FullName $file.FullName
        throw "Old NTPWEdit Enterprise development version found in $relative"
    }
}

# Scan public, user-facing documentation for obsolete contact links. Upstream
# source headers, HISTORY, COPYING, LICENSE, and NOTICE files intentionally keep
# legally relevant attribution and must not fail this audit.
$publicDocumentFiles = $allTextFiles | Where-Object {
    $relative = Get-RelativeRepositoryPath -Root $root -FullName $_.FullName
    $fileName = $_.Name

    ($relative -notlike 'src\*') -and (
        ($fileName -like 'README*') -or
        ($fileName -ieq 'CHANGELOG.md') -or
        ($relative -like 'docs\*') -or
        ($relative -like 'WinPE\*')
    )
}

foreach ($file in $publicDocumentFiles) {
    $relative = Get-RelativeRepositoryPath -Root $root -FullName $file.FullName

    # Explicitly exclude legal/historical attribution documents even when they
    # are located below a documentation directory.
    $baseName = $file.Name.ToUpperInvariant()
    if (($baseName -like 'LICENSE*') -or
        ($baseName -like 'COPYING*') -or
        ($baseName -like 'NOTICE*') -or
        ($baseName -like 'HISTORY*')) {
        continue
    }

    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text -match 'mailto:cdslow@mail\.ru|https?://cdslow\.org\.ru/ntpwedit/?|pnh@pogostick\.net') {
        throw "Obsolete visible contact metadata found in $relative"
    }
}

Write-Host "Project metadata audit passed for NTPWEdit Enterprise $ExpectedVersion." -ForegroundColor Green
Write-Host 'Upstream copyright, COPYING, LICENSE, HISTORY, and NOTICE attribution was preserved.' -ForegroundColor DarkGray
exit 0
