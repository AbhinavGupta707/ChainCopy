# Implementation Log

## 2026-06-19 - Persistence And Privacy

- Added a versioned JSON state file under Application Support for local settings and optional clipboard history.
- Kept clipboard item persistence off by default; settings still persist so privacy controls survive relaunch.
- Added retention controls for maximum item count and maximum item size, plus clear-on-quit handling.
- Added ignored app names, ignored bundle identifiers, ignored pasteboard types, and sensitive text pattern filters.
- Applied pasteboard type and source-app filters before reading clipboard text in the polling monitor.
- Added tests for persistence defaults, opt-in local history, retention, clearing, migration defaults, and privacy filtering.

Caveats:
- The local state file is plaintext when item persistence is enabled; this branch does not add encryption or Keychain storage.
- Diagnostics/crash reporting are not implemented in this scaffold, and this branch adds no clipboard-content logging.
