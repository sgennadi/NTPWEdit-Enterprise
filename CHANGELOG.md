# Changelog

All notable changes to NTPWEdit Enterprise are documented here.

## [1.0.0] - 2026-08-01

### Added

- Separate native `ntpwcli.exe` console target.
- Graphical builds for amd64, x86, and ARM64.
- Offline Windows installation discovery.
- Local-account inventory with separate disabled and locked states.
- Text and JSON output.
- Password change, unlock, enable, disable, backup, and restore operations.
- GUI command-line selection by SAM path, username, and RID.
- WinPE integration scripts.
- Automated CI, packaging, and GitHub Releases.
- SHA-256 checksums for release assets.
- Enterprise history section in `src/HISTORY.txt` while preserving upstream history.

### Changed

- Product versioning starts at `1.0.0`.
- Visible GUI product name is `NTPWEdit Enterprise 1.0.0`.
- Obsolete visible personal contact links were replaced by the project repository and third-party notice reference.
- English project documentation uses ASCII punctuation to avoid encoding corruption.
- GitHub Actions use Node.js 24-compatible action releases.

### Compatibility and attribution

- Based on the GPL-licensed NTPWEdit 0.7 codebase.
- Original source-file copyright notices, license texts, and upstream history are preserved.
