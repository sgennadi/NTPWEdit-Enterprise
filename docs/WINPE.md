# WinPE integration

The repository includes scripts that discover offline Windows installations and launch the architecture-matched GUI or `ntpwcli.exe`.

Recommended toolkit path:

```text
X:\RecoveryToolkit\PasswordReset\
```

Required WinPE optional components normally include PowerShell, WMI, Scripting, StorageWMI, and SecureStartup. Storage and network drivers must be injected separately when required by the hardware, including Intel VMD/RST packages.

Before modifying an account, create a backup of the offline registry hives and assess EFS/DPAPI risk.
