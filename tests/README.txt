NTPWEdit Enterprise 1.0.0 tests
================================

Run after the overlay has been applied to a fork:

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-SourceContract.ps1

Run source checks plus native ntpwcli smoke tests:

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-SourceContract.ps1 `
      -BinaryDirectory .\build-amd64\bin\Release

GitHub Actions performs:
- PowerShell parser validation;
- source-contract validation;
- x86, amd64, and ARM64 builds;
- PE architecture validation for GUI and ntpwcli;
- native /version, /?, /discover JSON smoke tests on x86 and amd64;
- artifact packaging and checksums.
