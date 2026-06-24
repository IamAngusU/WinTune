
# WinTune Advisor CLI Beta v0.2.0

A local-first Windows 10/11 performance assessment CLI with an interactive terminal UI, safety gating, per-action consent, fallback-aware collectors, optional telemetry, and a signed-update architecture.

## What this package includes

- `Client/` — friend-facing CLI and its local signed-update launcher.
- `Server/` — PHP/MySQL API, telemetry validation, beta enrollment, signed update-manifest serving, and a small funnel dashboard.
- `Tests/` — real-device test matrix and acceptance criteria.

## Important security model

The CLI **does not execute streamed PowerShell code from the server**. The launcher can only install a ZIP after it verifies:

1. HTTPS transport,
2. a signed update manifest using the locally pinned public certificate,
3. the ZIP SHA-256 from that signed manifest,
4. per-file hashes from `release.json` inside the ZIP.

The private update signing key stays only on the release server. Never place it in `Client/`, Git, a download ZIP, or your VPS web root.

## Fast local CLI test

On a Windows 10/11 test device, extract the ZIP and open PowerShell in `Client/`:

```powershell
.\WinTuneLauncher.ps1 -SampleSeconds 20
```

For elevated actions, launch PowerShell **as Administrator** first. The tool deliberately still works without elevation: it completes diagnostics and marks privileged actions as unavailable instead of failing.

For an initial friends phase, keep these defaults:

- `Client/BootstrapConfig.json` → `EnableUpdateCheck: false`
- `Client/App/appsettings.json` → `Telemetry.Enabled: false`

That gives you a safe **local diagnostic beta** before any server data collection.

## UX flow

1. User confirms whether unsaved work exists: `Y / N / U`.
2. `Y` and `U` activate Work Safety Mode: all state-changing actions are blocked.
3. Live scan shows actual phase progress and live CPU/RAM/disk/process-I/O data.
4. Findings are displayed with evidence and recommendation.
5. Interactive hosts show an arrow/space picker. Fallback hosts show a numbered picker.
6. The user must type `START` exactly before selected actions run.
7. Every action is revalidated immediately before execution.
8. HTML, JSON, CSV-like audit data, action results, and rollback records are written locally.

## Actions in this beta

- Enable NTFS TRIM if the scan found it disabled.
- ReTrim user-selected NTFS volumes.
- Delete old **current-user** TEMP files only (older than seven days; locked files skipped).
- Pause or resume Windows Search.
- Reduce current-user window/client-area animations.
- Enable High performance power plan and create a local rollback record.
- Run `chkdsk /scan` on a chosen volume.
- Review and disable a supported Registry `Run` startup entry after JSON backup.

The CLI does **not** automatically move files, alter pagefile settings, change arbitrary services, disable security tools, update drivers, edit BIOS/firmware, run registry cleaners, or perform SSD defragmentation.

## Update server setup

Use a domain that points to `72.61.187.78`, such as `updates.your-domain.tld`. Do not use a raw IP for client updates: the client requires HTTPS and certificate validation.

1. Deploy `Server/` outside the public web root where practical.
2. Create MySQL database/user and import `Server/database/schema.sql`.
3. Copy `Server/.env.example` to `Server/.env`, set secrets, database credentials, and release root.
4. Configure Nginx from `Server/nginx/wintune.conf.example`, then issue a valid TLS certificate.
5. On the server, create an update-signing keypair:

```bash
cd Server/scripts
./generate_update_key.sh /secure/wintune-keys
```

6. Copy **only** `/secure/wintune-keys/update-signing-public.cer` to:

```text
Client/Bootstrap/keys/update-signing-public.cer
```

7. Configure `Client/BootstrapConfig.json`:

```json
{
  "EnableUpdateCheck": true,
  "UpdateManifestUrl": "https://updates.your-domain.tld/v1/updates/manifest?channel=beta"
}
```

8. Configure `Client/App/appsettings.json` only when you are ready for opt-in telemetry:

```json
{
  "Telemetry": {
    "Enabled": true,
    "EnrollmentEndpoint": "https://updates.your-domain.tld/v1/enroll",
    "EventEndpoint": "https://updates.your-domain.tld/v1/telemetry/events",
    "FeedbackEndpoint": "https://updates.your-domain.tld/v1/feedback"
  }
}
```

9. Build a signed release on the server:

```bash
php Server/scripts/build_release.php \
  --app-dir=/path/to/WinTuneAdvisor/Client/App \
  --client-dir=/path/to/WinTuneAdvisor/Client \
  --release-root=/var/www/wintune/storage/releases \
  --base-url=https://updates.your-domain.tld \
  --channel=beta \
  --version=0.2.1 \
  --private-key=/secure/wintune-keys/update-signing-private.pem
```

The client checks the manifest with a short timeout. If the server is unavailable, the launcher logs the reason locally and starts its last local version. A failed update never blocks diagnostics.

## Telemetry and funnel data

Telemetry is opt-in after the scan. The minimized payload contains only technical buckets and statuses: Windows version/build, PowerShell major version, admin state, disk transport types, collector statuses, rule IDs, action statuses, and pseudonymous installation/session UUIDs.

It intentionally excludes usernames, computer names, IP addresses, full paths, startup commands, raw event-log messages, serial numbers, hardware IDs, file names, and process command lines.

The server dashboard is at:

```text
https://updates.your-domain.tld/admin
```

It shows scans received, common rule hits, action outcomes, and collector compatibility. It uses HTTP Basic Auth; enable it only behind HTTPS and use a strong password hash.

## First beta plan

Keep it simple:

1. Run diagnostics only on your PC, a Windows 10 PC, a Windows 11 laptop, and a standard-user account.
2. Verify that all reports are created even when a collector is `Skipped`, `Degraded`, or `FailedNonFatal`.
3. Test unsaved-work `Y` and `U`: no action may become executable.
4. Test each action individually on a non-critical machine, then compare before/after reports.
5. Enable telemetry only after you review `TelemetryPreview.json` and deploy the API over HTTPS.

Read `Tests/TestMatrix.md` before inviting friends.

## Production note

This is a beta engineering foundation, not a claim that every Windows configuration has been certified. Before paid distribution, sign the PowerShell files (Authenticode), ship a signed native launcher or installer, complete the test matrix on physical Windows 10/11 devices, and run a privacy/security review of the hosted telemetry service.
