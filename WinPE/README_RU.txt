NTPWEdit Enterprise 1.0.0 - WinPE integration
================================================

Start-PasswordReset.cmd запускает интерактивное меню.

Структура после интеграции:

  RecoveryToolkit\
    Invoke-NTPWEditEnterprise.ps1
    Find-WindowsInstallations.ps1
    Start-PasswordReset.cmd
    Modules\PasswordReset.ps1
    Tools\PasswordReset\amd64\ntpwedit64.exe
    Tools\PasswordReset\amd64\ntpwcli.exe
    Tools\PasswordReset\x86\ntpwedit.exe
    Tools\PasswordReset\x86\ntpwcli.exe
    Tools\PasswordReset\arm64\ntpweditarm64.exe
    Tools\PasswordReset\arm64\ntpwcli.exe

Возможности меню:
- автоматический поиск offline Windows;
- разблокирование BitLocker recovery password;
- список локальных пользователей с отдельными Disabled/Locked флагами;
- запуск GUI с уже выбранными SAM и RID пользователя;
- Unlock, Enable, Disable, Unlock+Enable;
- скрытый ввод нового пароля;
- Unlock+Enable+Password за одну запись SAM;
- очистка пароля после отдельного подтверждения;
- автоматическая копия SAM/SYSTEM/SECURITY/DEFAULT/SOFTWARE до изменений;
- восстановление резервной копии;
- JSON-экспорт и аудит без записи пароля.

Логи и резервные копии:
  <WindowsDrive>:\RecoveryLogs\NTPWEdit\

Работает только с локальными offline SAM-учётными записями.
