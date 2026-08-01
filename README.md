# NTPWEdit Enterprise

[![CI](https://github.com/sgennadi/NTPWEdit-Enterprise/actions/workflows/ci.yml/badge.svg)](https://github.com/sgennadi/NTPWEdit-Enterprise/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/sgennadi/NTPWEdit-Enterprise?display_name=tag)](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/sgennadi/NTPWEdit-Enterprise/total)](https://github.com/sgennadi/NTPWEdit-Enterprise/releases)
[![License](https://img.shields.io/github/license/sgennadi/NTPWEdit-Enterprise)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-amd64%20%7C%20x86%20%7C%20ARM64-blue)](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest)

Offline Windows local-account recovery for WinPE with a graphical interface, a separate console application, JSON output, and automated builds for amd64, x86, and ARM64.

> **Administrative recovery tool:** use only on systems you own or are authorized to support.

## Current release

**v1.0.0**

## Download

| Package | Platform | Download |
|---|---|---|
| NTPWEdit Enterprise amd64 | 64-bit Intel/AMD Windows and WinPE | [Download](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-amd64.zip) |
| NTPWEdit Enterprise x86 | 32-bit Windows and WinPE | [Download](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-x86.zip) |
| NTPWEdit Enterprise ARM64 | ARM64 Windows and WinPE | [Download](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-arm64.zip) |
| All architectures | Complete package | [Download](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/NTPWEdit-Enterprise-All.zip) |
| SHA-256 checksums | Release verification | [Download](https://github.com/sgennadi/NTPWEdit-Enterprise/releases/latest/download/SHA256SUMS.txt) |

All releases are also available on the [Releases page](https://github.com/sgennadi/NTPWEdit-Enterprise/releases).

## Included applications

- `ntpwedit64.exe`, `ntpwedit.exe`, and `ntpweditarm64.exe` - graphical interface.
- `ntpwcli.exe` - native console application for inventory, status, JSON output, backup, restore, password change, unlock, enable, and disable operations.
- WinPE integration scripts for automatic Windows installation discovery and recovery workflows.

## Main features

- Offline local SAM account inventory.
- Separate `disabled` and `locked` account states.
- Account unlock, enable, disable, and password reset.
- Hidden password input; passwords are not accepted as ordinary command-line arguments.
- JSON and text output.
- Registry-hive backup before destructive changes.
- Automatic discovery of offline Windows installations.
- GUI command-line selection by SAM path, username, or RID.
- amd64, x86, and ARM64 builds.
- GitHub Actions CI and automated GitHub Releases.

## Console examples

List local users:

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list
```

Export JSON:

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list /format json /output users.json
```

Unlock and enable an account:

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /unlock-enable --confirm WRITE
```

Set a password through hidden input:

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /password-prompt --confirm WRITE
```

See [CLI documentation](docs/CLI.md) and [WinPE integration](docs/WINPE.md).

## Account scope

NTPWEdit Enterprise works with **local accounts stored in an offline Windows SAM database**. It does not reset:

- Active Directory domain passwords;
- Microsoft Entra ID credentials;
- personal Microsoft Account passwords;
- Windows Hello PIN credentials.

## Build

```powershell
cmake -S src -B build-amd64 -A x64 `
  -DNTPWEDIT_BUILD_GUI=ON `
  -DNTPWEDIT_BUILD_CLI=ON `
  -DNTPWEDIT_ENABLE_TESTS=ON

cmake --build build-amd64 --config Release --parallel
```

The repository workflows build all supported architectures and publish ZIP files to GitHub Releases when a version tag such as `v1.0.0` is pushed.

## Documentation

- [Russian README](README_RU.md)
- [CLI reference](docs/CLI.md)
- [WinPE integration](docs/WINPE.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Detailed project and upstream history](src/HISTORY.txt)
- [Contributing](CONTRIBUTING.md)

## License and attribution

This project is derived from NTPWEdit and remains subject to the upstream GPL licensing terms. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
