# NTPWEdit Enterprise

[![CI](https://github.com/sgennadi/NTPWEdit-Enterprise/actions/workflows/ci.yml/badge.svg)](https://github.com/sgennadi/NTPWEdit-Enterprise/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/sgennadi/NTPWEdit-Enterprise?display_name=tag)](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/sgennadi/NTPWEdit-Enterprise/total)](https://github.com/sgennadi/NTPWEdit-Enterprise/releases)
[![License](https://img.shields.io/github/license/sgennadi/NTPWEdit-Enterprise)](LICENSE)

Расширенный инструмент восстановления локальных учётных записей Windows из WinPE: графическая версия, отдельная консольная программа `ntpwcli.exe`, JSON, amd64, x86 и ARM64.

> Используйте только на компьютерах, которые вы имеете право обслуживать.

## Текущая версия

**v1.0.0**

## Скачать EXE

| Пакет | Платформа | Ссылка |
|---|---|---|
| amd64 | 64-битные Intel/AMD Windows и WinPE | [Скачать](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-amd64.zip) |
| x86 | 32-битные Windows и WinPE | [Скачать](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-x86.zip) |
| ARM64 | ARM64 Windows и WinPE | [Скачать](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-arm64.zip) |
| Все архитектуры | Полный комплект | [Скачать](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-All.zip) |
| SHA-256 | Контрольные суммы | [Скачать](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/SHA256SUMS.txt) |

Полный список версий: [GitHub Releases](https://github.com/sgennadi/NTPWEdit-Enterprise/releases).

## Возможности

- просмотр локальных пользователей offline Windows;
- отдельное отображение `disabled` и `locked`;
- unlock, enable, disable;
- установка нового пароля через скрытый ввод;
- JSON и текстовый вывод;
- backup системных registry hives;
- автоматический поиск установленных Windows;
- выбор пользователя по имени или RID;
- GUI и отдельный `ntpwcli.exe`;
- сборка amd64, x86 и ARM64;
- автоматическая публикация GitHub Release.

## Примеры ntpwcli.exe

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list
```

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list /format json /output users.json
```

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /unlock-enable --confirm WRITE
```

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /password-prompt --confirm WRITE
```

## Ограничение

Программа работает с **локальными учётными записями в offline SAM**. Она не сбрасывает пароли Active Directory, Microsoft Entra ID, личной Microsoft Account или Windows Hello PIN.

## Документация

- [CLI](docs/CLI.md)
- [WinPE](docs/WINPE.md)
- [История версий](CHANGELOG.md)
- [Безопасность](SECURITY.md)

## История проекта

- [История NTPWEdit Enterprise и сохранённая история upstream](src/HISTORY.txt)
- [Список изменений](CHANGELOG.md)
