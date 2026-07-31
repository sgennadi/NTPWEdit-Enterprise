@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"

if not exist "%ROOT%Invoke-NTPWEditEnterprise.ps1" (
    echo ERROR: Invoke-NTPWEditEnterprise.ps1 was not found.
    exit /b 2
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Invoke-NTPWEditEnterprise.ps1" -Mode Menu
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo NTPWEdit Enterprise exited with code %RC%.
exit /b %RC%
