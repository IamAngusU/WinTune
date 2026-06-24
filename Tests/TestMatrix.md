
# Real-device test matrix

## Acceptance rule

No test may produce an unhandled terminating error. A collector/action failure must be represented as `Skipped`, `Degraded`, or `FailedNonFatal`, and a local report must still be written.

## Minimum friends beta matrix

| ID | OS | Shell | Rights | Storage | Device state | Expected focus |
|---|---|---|---|---|---|---|
| M01 | Windows 10 | PowerShell 5.1 | Standard | SATA SSD | Normal | No-admin graceful behavior |
| M02 | Windows 10 | PowerShell 7 stable | Admin | HDD + SSD | Normal | Mixed storage detection |
| M03 | Windows 11 | PowerShell 5.1 | Admin | NVMe | Normal | Storage reliability/Trim |
| M04 | Windows 11 | PowerShell 7 stable | Standard | NVMe | C: low free space | Rule accuracy, no actions |
| M05 | Windows 11 | PowerShell 7 stable | Admin | NVMe | Active heavy writing | Live I/O and safety gate |
| M06 | Windows 11 laptop | PowerShell 5.1 | Admin | SATA SSD | Battery | Power-plan trade-off |
| M07 | Windows 10 | PowerShell 5.1 | Admin | HDD | Search indexing | WSearch action |
| M08 | Windows 11 | PowerShell 7 stable | Admin | Any | OneDrive desktop | Report-path fallback |

## Per-device protocol

1. Record only Matrix ID, OS, shell, rights, storage type, and run date in your private test sheet.
2. Run `WinTuneLauncher.ps1 -SampleSeconds 20`.
3. Test Work Safety Mode with `Y` or `U`.
4. Verify actions are blocked and the report exists.
5. Run again with `N`, but decline all actions. Confirm no configuration changed.
6. On non-critical test systems, test **one** eligible action at a time and capture before/after reports.
7. Record whether output was understandable and whether any collector was partial.
8. Only after the local test passes, opt in to telemetry and check the dashboard event.

## Required negative cases

| Case | Expected result |
|---|---|
| Not admin | Analysis continues; privileged action has a human-readable block reason |
| UAC not used | Same as standard-user run |
| Update server offline | Local engine starts; launcher log mentions unavailable update check |
| No update certificate | Local engine starts; update check is skipped/failed non-fatally |
| WMI/CIM collector failure | Collector is degraded/skipped; report remains available |
| Event log unavailable | Only event collector is skipped |
| No reliability counters | Disk base info remains available without invented telemetry |
| TEMP file locked | Cleanup skips it and reports skipped count |
| Telemetry API returns 500 | Local scan succeeds and payload is queued locally |
| Telemetry disabled | No enrollment prompt and no network request |
| Unsaved work = Y/U | No selected action can execute |
| English and German Windows | Rules cannot depend on localized command descriptions |

## Release gate for the next beta

- At least 30 full diagnostic runs.
- Zero unhandled crashes.
- Zero state changes during Diagnostic-only runs or after declined final confirmation.
- Every telemetry payload passes server validation.
- Each included action has at least five successful and independently reviewed test runs.
- Any action with a verification failure rate above 2% is disabled from the remote release/channel until investigated.
