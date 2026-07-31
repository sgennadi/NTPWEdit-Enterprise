# ntpwcli.exe reference

## Discovery

```cmd
ntpwcli.exe /discover
ntpwcli.exe /discover /format json /output installations.json
```

## Inventory

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /list
```

## Status

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /status
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /user Administrator /status /format json
```

## Write operations

Write operations require an explicit confirmation token.

```cmd
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /unlock --confirm WRITE
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /enable --confirm WRITE
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /unlock-enable --confirm WRITE
ntpwcli.exe /sam "D:\Windows\System32\Config\SAM" /rid 500 /password-prompt --confirm WRITE
```

Do not pass a plaintext password as a normal process argument.
