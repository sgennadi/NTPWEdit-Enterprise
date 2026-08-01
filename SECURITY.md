# Security policy

## Supported version

The latest GitHub Release is the supported version.

## Reporting a vulnerability

Do not disclose security-sensitive defects in a public issue. Contact the repository owner privately through GitHub before publishing technical details.

## Operational safety

NTPWEdit Enterprise modifies offline Windows registry hives. Before a write operation:

1. Verify that you are authorized to service the computer.
2. Back up SAM, SYSTEM, SECURITY, SOFTWARE, and DEFAULT hives.
3. Check for EFS- or DPAPI-protected data.
4. Keep the computer disconnected from untrusted networks.
5. Verify downloaded packages against `SHA256SUMS.txt`.

Passwords, recovery keys, and authentication tokens must never be written to logs, issue reports, or command-line arguments.
