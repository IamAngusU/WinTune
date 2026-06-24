
#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SkipUpdateCheck,
    [switch]$NoPause,
    [ValidateRange(5,180)][int]$SampleSeconds = 20
)

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'WinTune Advisor supports Windows only.' -ForegroundColor Red
    exit 1
}

$launcherRoot = $PSScriptRoot
$modulePath = Join-Path $launcherRoot 'Bootstrap\Wta.UpdateBootstrap.psm1'
Import-Module $modulePath -Force -DisableNameChecking

$dataRoot = Get-WtaBootstrapRoot
$configObj = Get-WtaBootstrapConfig -LauncherRoot $launcherRoot
$config = @{}
foreach ($key in $configObj.Keys) { $config[$key] = $configObj[$key] }

try {
    Ensure-WtaInitialVersion -LauncherRoot $launcherRoot -DataRoot $dataRoot -Config $config
}
catch {
    Write-Host ("Unable to initialize local version: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}

$current = Get-WtaCurrentVersionRecord -DataRoot $dataRoot
Write-Host ("WinTune Advisor launcher - local version {0}" -f $current.version) -ForegroundColor Cyan

if (-not $SkipUpdateCheck -and [bool]$config.EnableUpdateCheck -and -not [string]::IsNullOrWhiteSpace([string]$config.UpdateManifestUrl)) {
    try {
        Write-Host 'Checking for signed updates...' -ForegroundColor DarkGray
        $response = Invoke-WtaBootstrapWeb -Uri ([string]$config.UpdateManifestUrl) -TimeoutSeconds 3
        $certificatePath = Join-Path $launcherRoot ([string]$config.PublicCertificateFile)
        $manifest = Test-WtaManifestEnvelope -EnvelopeJson $response.Content -CertificatePath $certificatePath

        if (Test-WtaVersionGreater -Candidate ([string]$manifest.version) -Current ([string]$current.version)) {
            Write-Host ''
            Write-Host ("Update available: {0}" -f $manifest.version) -ForegroundColor Yellow
            foreach ($note in @($manifest.releaseNotes)) { Write-Host (" - {0}" -f $note) -ForegroundColor DarkGray }

            $choice = Read-Host 'Update now? (U=update, S=skip, C=continue)'
            if ($choice -ieq 'U') {
                $installedPath = Install-WtaUpdate -DataRoot $dataRoot -Manifest $manifest
                Write-Host ("Verified update installed: {0}" -f $installedPath) -ForegroundColor Green
                $current = Get-WtaCurrentVersionRecord -DataRoot $dataRoot
            }
            elseif ($choice -ieq 'S') {
                Write-WtaBootstrapLog -Root $dataRoot -Message ("Skipped update {0}" -f $manifest.version)
            }
        }
    }
    catch {
        # Offline or update faults must never block a verified local version.
        Write-WtaBootstrapLog -Root $dataRoot -Message ("Update check unavailable: {0}" -f $_.Exception.Message)
        Write-Host 'Update check unavailable. Starting the verified local version.' -ForegroundColor DarkGray
    }
}

$appPath = Join-Path $current.path 'WinTuneAdvisor.ps1'
if (-not (Test-Path -LiteralPath $appPath)) {
    Write-Host "Active engine is missing: $appPath" -ForegroundColor Red
    exit 1
}

& $appPath -BootstrapRoot $dataRoot -SampleSeconds $SampleSeconds -NoPause:$NoPause
exit $LASTEXITCODE
