@echo off
REM NTPWEdit Enterprise 1.0.0 command examples. Run only on an authorized offline Windows installation.

REM Original GUI with command-line preselection.
ntpwedit64.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /open
ntpwedit64.exe /windows "D:\Windows" /user Administrator /open

REM Native console application.
ntpwcli.exe /discover /format json
ntpwcli.exe /auto /select 1 /list
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list /format json /output users.json
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /status /format json
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /backup "E:\NTPWBackup"
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /unlock-enable /password-prompt --confirm WRITE
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /restore "E:\NTPWBackup" --confirm RESTORE
