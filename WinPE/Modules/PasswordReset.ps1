# Password Reset module for a larger WinPE Recovery Toolkit.
Set-StrictMode -Version 2.0

function Start-NTPWEditPasswordReset {
    [CmdletBinding()]
    param(
        [string]$ToolkitRoot,
        [switch]$NoAutomaticBackup
    )

    if (-not $ToolkitRoot) {
        $ToolkitRoot = Split-Path -Parent $PSScriptRoot
    }
    $launcher = Join-Path $ToolkitRoot 'Invoke-NTPWEditEnterprise.ps1'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
        throw "NTPWEdit Enterprise launcher was not found: $launcher"
    }

    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$launcher,'-Mode','Menu')
    if ($NoAutomaticBackup) { $arguments += '-NoAutomaticBackup' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "NTPWEdit Enterprise returned exit code $LASTEXITCODE."
    }
}

Export-ModuleMember -Function Start-NTPWEditPasswordReset
