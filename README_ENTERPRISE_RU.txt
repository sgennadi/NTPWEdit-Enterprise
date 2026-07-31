NTPWEdit Enterprise 1.0.0
==========================

ПЕРВЫЙ ОФИЦИАЛЬНЫЙ РЕЛИЗ
------------------------
Версия проекта начинается заново с 1.0.0.

Номера 3.x использовались только для промежуточных пакетов разработки и
не являются историей официальных релизов. Первый GitHub tag и Release:

    v1.0.0

Версии внутри программ:

    NTPWEdit Enterprise 1.0.0      GUI
    NTPWEdit Enterprise CLI 1.0.0  ntpwcli.exe

Старая строка оригинального GUI "NTPWEdit 0.7" заменяется при сборке на
"NTPWEdit Enterprise 1.0.0". Сведения об исходном авторе и лицензия GPL
сохраняются.

ЧТО СОБИРАЕТСЯ
---------------
AMD64:
    ntpwedit64.exe
    ntpwcli.exe

x86:
    ntpwedit.exe
    ntpwcli.exe

ARM64:
    ntpweditarm64.exe
    ntpwcli.exe

БЫСТРЫЙ ЗАПУСК
--------------
1. Распакуйте архив в новую папку, например:

       C:\Users\Student\Downloads\NTPWEdit-Enterprise-v1.0.0-CLEAN

2. Для сборки и публикации GitHub одним запуском используйте:

       Run-All.cmd

   Только собрать и скачать EXE:

       Run-Setup.cmd

3. Скрипт:
   - проверит Git и GitHub CLI;
   - выполнит вход в GitHub;
   - создаст или повторно использует fork NTPWEdit-Mirror;
   - заново создаст ветку enterprise-cli от чистого upstream/main;
   - применит Enterprise 1.0.0 один раз;
   - изменит версию GUI с 0.7 на 1.0.0;
   - выполнит локальную AMD64-проверку, если доступен CMake;
   - отправит исходники в GitHub;
   - соберёт AMD64, x86 и ARM64 через GitHub Actions;
   - скачает готовые EXE.

ГДЕ БУДУТ EXE
-------------

    %USERPROFILE%\Downloads\NTPWEdit-EXE\
        amd64\
            ntpwedit64.exe
            ntpwcli.exe
        x86\
            ntpwedit.exe
            ntpwcli.exe
        arm64\
            ntpweditarm64.exe
            ntpwcli.exe
        NTPWEdit-Enterprise-1.0.0-Binaries.zip
        SHA256SUMS.txt
        BUILD-INFO.txt

ПУБЛИКАЦИЯ КАК ОТДЕЛЬНОГО GITHUB-ПРОЕКТА
----------------------------------------
После успешной сборки запустите:

    Publish-GitHub.cmd

Будет создан или обновлён самостоятельный repository. Старые development Release/tag v3.x и v0.7x в этом отдельном repository удаляются, чтобы официальная история начиналась с v1.0.0:

    sgennadi/NTPWEdit-Enterprise

На GitHub появятся:
- README на английском и русском;
- описание и topics;
- CI и Release workflows;
- tag v1.0.0;
- Release v1.0.0;
- ZIP с EXE для AMD64, x86 и ARM64;
- общий ZIP;
- SHA256SUMS.txt.

Дополнительные команды:

    Publish-GitHub-Source-Only.cmd
    Publish-GitHub-Release-Only.cmd

ВЕРСИЯ В GUI
------------
Apply-EnterpriseCLI.ps1 изменяет src\version.c. В окне About и заголовке
программы отображается:

    NTPWEdit Enterprise 1.0.0 (64-bit)
    NTPWEdit Enterprise 1.0.0 (32-bit)
    NTPWEdit Enterprise 1.0.0 (ARM64)

CLI
---

    ntpwcli.exe /version
    ntpwcli.exe /?
    ntpwcli.exe /discover /format json
    ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list

ОГРАНИЧЕНИЯ
-----------
Инструмент работает только с локальными учётными записями в offline SAM.
Он не меняет пароли Active Directory, Microsoft Entra ID, личной Microsoft
Account или Windows Hello.

Используйте инструмент только на системах, которые вы уполномочены
обслуживать. Перед изменением SAM создавайте резервную копию.

ABOUT / СВЕДЕНИЯ О ПРОГРАММЕ
-----------------------------
В видимом окне About отображаются только:
- NTPWEdit Enterprise 1.0.0 и архитектура;
- NTPWEdit Enterprise project;
- ссылка на https://github.com/sgennadi/NTPWEdit-Enterprise;
- ссылка-текст на LICENSE-ENTERPRISE-NOTICE.txt.

Устаревшие личный email, старый сайт и имена прежних авторов удалены из
видимого окна About. Обязательные исходные copyright-заголовки и сведения
об авторах стороннего GPL/LGPL-кода сохраняются в исходниках и NOTICE-файле.
