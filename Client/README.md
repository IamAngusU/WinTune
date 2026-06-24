# Start WinTune

1. Download and extract the starter ZIP to a local folder, such as Downloads.
2. Double-click `Start-WinTune.cmd`.
3. Read the onscreen prompts and choose the actions you want to run.

The starter opens PowerShell for this one run only. It does not change Windows execution-policy settings. Do not run WinTune from a network share.

For actions that need administrator rights, right-click `Start-WinTune.cmd` and choose **Run as administrator**. Diagnostics and reports work without administrator rights.

## What happens to beta data

WinTune creates a random installation UUID in `%LOCALAPPDATA%\WinTuneAdvisor\identity.json`. It is used only to correlate voluntary beta reports from the same installation. The server stores an HMAC hash of that UUID, not the UUID itself. A beta access token is protected using Windows DPAPI for the current user.

Telemetry is optional. It starts only after explicit consent and a valid beta code. See the [privacy section](https://angusu.de/docs/wintune/#telemetry) for the exact fields.

The published beta checks the signed update endpoint. Telemetry stays optional and requires a separate confirmation.

`WinTuneLauncher.ps1` is the stable entrypoint. It prepares a versioned local cache under:

```text
%LOCALAPPDATA%\WinTuneAdvisor\
```

It can later verify signed package updates and roll forward only after verification. It does not download and execute arbitrary remote scripts.
