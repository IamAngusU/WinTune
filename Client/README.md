# Client quick start

Extract the package to a local folder. Do not run the engine from a network share.

```powershell
cd .\Client
.\WinTuneLauncher.ps1 -SampleSeconds 20
```

For administrator-only actions, open a PowerShell window **as Administrator** and run the same command.

The default beta configuration has remote update checks and telemetry disabled. Configure them only after you deploy the server over a real HTTPS domain and add the pinned public update certificate.

`WinTuneLauncher.ps1` is the stable entrypoint. It prepares a versioned local cache under:

```text
%LOCALAPPDATA%\WinTuneAdvisor\
```

It can later verify signed package updates and roll forward only after verification. It does not download and execute arbitrary remote scripts.
