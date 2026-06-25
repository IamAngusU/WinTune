
#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SkipUpdateCheck,
    [switch]$NoPause,
    [ValidateRange(5,180)][int]$SampleSeconds = 20
)

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'WinTune Advisor supports Windows only. / WinTune Advisor unterstützt nur Windows.' -ForegroundColor Red
    exit 1
}

$launcherRoot = $PSScriptRoot
$modulePath = Join-Path $launcherRoot 'Bootstrap\Wta.UpdateBootstrap.psm1'
Import-Module $modulePath -Force -DisableNameChecking

$dataRoot = Get-WtaBootstrapRoot
$configObj = Get-WtaBootstrapConfig -LauncherRoot $launcherRoot
$config = @{}
foreach ($key in $configObj.Keys) { $config[$key] = $configObj[$key] }
$language = Select-WtaBootstrapLanguage -Root $dataRoot

try {
    Ensure-WtaInitialVersion -LauncherRoot $launcherRoot -DataRoot $dataRoot -Config $config
    $bundledPath = Use-WtaBundledVersionIfNewer -LauncherRoot $launcherRoot -DataRoot $dataRoot -Config $config
    if ($bundledPath) {
        Write-Host ((Get-WtaBootstrapText -Language $language -Key 'BundledActivated') -f ([string]$config.InitialVersion)) -ForegroundColor Green
    }
}
catch {
    Write-Host ((Get-WtaBootstrapText -Language $language -Key 'InitFailed') -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}

$current = Get-WtaCurrentVersionRecord -DataRoot $dataRoot
Write-Host ((Get-WtaBootstrapText -Language $language -Key 'LocalVersion') -f $current.version) -ForegroundColor Cyan
Send-WtaBootstrapFunnelEvent -Root $dataRoot -Config $config -EventName 'launcher_started' -ReleaseVersion ([string]$current.version)

if (-not $SkipUpdateCheck -and [bool]$config.EnableUpdateCheck -and -not [string]::IsNullOrWhiteSpace([string]$config.UpdateManifestUrl)) {
    try {
        Write-Host (Get-WtaBootstrapText -Language $language -Key 'CheckingUpdates') -ForegroundColor DarkGray
        $response = Invoke-WtaBootstrapWeb -Uri ([string]$config.UpdateManifestUrl) -TimeoutSeconds 3
        Send-WtaBootstrapFunnelEvent -Root $dataRoot -Config $config -EventName 'update_manifest_checked' -ReleaseVersion ([string]$current.version)
        $certificatePath = Join-Path $launcherRoot ([string]$config.PublicCertificateFile)
        $manifest = Test-WtaManifestEnvelope -EnvelopeJson $response.Content -CertificatePath $certificatePath

        if (Test-WtaVersionGreater -Candidate ([string]$manifest.version) -Current ([string]$current.version)) {
            Send-WtaBootstrapFunnelEvent -Root $dataRoot -Config $config -EventName 'update_available' -ReleaseVersion ([string]$manifest.version)
            Write-Host ''
            Write-Host ((Get-WtaBootstrapText -Language $language -Key 'UpdateAvailable') -f $manifest.version) -ForegroundColor Yellow
            foreach ($note in @($manifest.releaseNotes)) { Write-Host (" - {0}" -f $note) -ForegroundColor DarkGray }

            $choice = Read-Host ((Get-WtaBootstrapText -Language $language -Key 'UpdatePrompt') + ' [U]')
            if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 'U' }
            if ($choice -ieq 'U') {
                $installedPath = Install-WtaUpdate -DataRoot $dataRoot -Manifest $manifest
                Write-Host ((Get-WtaBootstrapText -Language $language -Key 'UpdateInstalled') -f $installedPath) -ForegroundColor Green
                $current = Get-WtaCurrentVersionRecord -DataRoot $dataRoot
                Send-WtaBootstrapFunnelEvent -Root $dataRoot -Config $config -EventName 'update_installed' -ReleaseVersion ([string]$current.version)
            }
            else {
                Write-WtaBootstrapLog -Root $dataRoot -Message ("Deferred update {0}" -f $manifest.version)
                Send-WtaBootstrapFunnelEvent -Root $dataRoot -Config $config -EventName 'update_skipped' -ReleaseVersion ([string]$manifest.version)
                Write-Host (Get-WtaBootstrapText -Language $language -Key 'UpdateDeferred') -ForegroundColor DarkGray
            }
        }
    }
    catch {
        # Offline or update faults must never block a verified local version.
        Write-WtaBootstrapLog -Root $dataRoot -Message ("Update check unavailable: {0}" -f $_.Exception.Message)
        Send-WtaBootstrapFunnelEvent -Root $dataRoot -Config $config -EventName 'update_manifest_failed' -ReleaseVersion ([string]$current.version)
        Write-Host (Get-WtaBootstrapText -Language $language -Key 'UpdateUnavailable') -ForegroundColor DarkGray
    }
}

$appPath = Join-Path $current.path 'WinTuneAdvisor.ps1'
if (-not (Test-Path -LiteralPath $appPath)) {
    Write-Host ((Get-WtaBootstrapText -Language $language -Key 'EngineMissing') -f $appPath) -ForegroundColor Red
    exit 1
}

& $appPath -BootstrapRoot $dataRoot -Language $language -SampleSeconds $SampleSeconds -NoPause:$NoPause
exit $LASTEXITCODE
