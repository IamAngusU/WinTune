# WinTune

Local-first Windows diagnostics and maintenance with explicit actions, practical rollback records, and a signed update chain.

[Download WinTune](https://angusu.de/wintune/) · [Documentation](https://angusu.de/docs/wintune/) · [Releases](https://github.com/IamAngusU/WinTune/releases)

## What it does

WinTune inspects Windows 10 and 11 systems, presents evidence for each recommendation, and lets the user choose which maintenance actions to run. It is designed for transparent operation rather than silent background tuning.

- Local diagnostics work without administrator rights.
- State-changing actions require selection and an exact `START` confirmation.
- Work Safety Mode blocks actions when unsaved work may exist.
- Reports and rollback records stay on the local machine.
- Optional beta telemetry is minimized, consent-based, and protected by an enrollment token.

## Release integrity

The launcher never runs code streamed from the server. Before installing an update, it verifies HTTPS, the manifest signature against a bundled public certificate, the package SHA-256, and the hash of every packaged file.

The private signing key is not part of this repository, any release ZIP, or the web root.

## Quick start

Download and extract the starter ZIP, then run:

```powershell
.\WinTuneLauncher.ps1
```

For privileged actions, start PowerShell as Administrator. The diagnostic flow still runs in a standard-user session.

## Repository layout

| Path | Purpose |
| --- | --- |
| `Client/` | Launcher, local application, update verification, and telemetry client |
| `Server/` | PHP API, telemetry validation, database schema, release builder, and Nginx route configuration |
| `Tests/` | Device test matrix and acceptance criteria |
| `assets/` | Landing page presentation assets |

## Hosted beta

The hosted service exposes a signed update manifest and an opt-in telemetry API. Runtime configuration, release packages, manifests, private signing material, and database credentials are intentionally excluded from Git.

Release publication is manually initiated through GitHub Actions and requires approval in the `production` environment. See [DEPLOYMENT.md](DEPLOYMENT.md) for server and release setup.

## Boundaries

WinTune does not update drivers, modify firmware, disable security software, change arbitrary services, edit pagefile settings, use registry cleaners, or perform SSD defragmentation. Read [Tests/TestMatrix.md](Tests/TestMatrix.md) before testing an action on a non-critical machine.

## License

This repository is published for open review during the beta. Distribution and commercial terms may change before a production release.
