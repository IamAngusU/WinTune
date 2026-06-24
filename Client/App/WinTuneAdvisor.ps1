
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$BootstrapRoot = '',
    [ValidateRange(5,180)][int]$SampleSeconds = 20,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    Write-Host 'This engine supports Windows only.' -ForegroundColor Red
    exit 1
}

$moduleRoot = Join-Path $PSScriptRoot 'Modules'
foreach ($module in @('Wta.Common.psm1','Wta.Tui.psm1','Wta.Collectors.psm1','Wta.Rules.psm1','Wta.Actions.psm1','Wta.Telemetry.psm1')) {
    Import-Module (Join-Path $moduleRoot $module) -Force -DisableNameChecking
}

$context = $null
$outputRoot = $null
try {
    $settings = Get-WtaJsonFile -Path (Join-Path $PSScriptRoot 'appsettings.json')
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) {
        $desktop = Join-Path $env:LOCALAPPDATA 'WinTuneAdvisor\reports'
    }
    $outputRoot = Join-Path $desktop ("WinTuneAdvisor_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $outputRoot -Force -ErrorAction Stop | Out-Null
    $context = New-WtaContext -OutputRoot $outputRoot -Settings $settings -BootstrapRoot $BootstrapRoot

    Write-WtaBanner -Context $context
    Write-Host 'No telemetry is sent unless you explicitly opt in after the scan.' -ForegroundColor DarkGray
    if ($context.IsAdministrator) {
        Write-Host 'Administrator session detected. Eligible elevated actions can be selected later.' -ForegroundColor Green
    } else {
        Write-Host 'Standard-user session detected. Diagnostics and current-user actions remain available.' -ForegroundColor Yellow
        Write-Host 'For the full action set, close WinTune, right-click Start-WinTune.cmd, and choose "Run as administrator".' -ForegroundColor Yellow
        Write-Host 'Nothing is blocked silently: actions that need elevation are clearly marked.' -ForegroundColor DarkGray
    }

    Set-WtaWorkSafetyMode -Context $context

    Write-Host ''
    Write-Host 'LIVE ANALYSIS' -ForegroundColor Cyan
    Write-Host 'The scan is read-only. A partial report is retained even when a collector is unavailable.' -ForegroundColor DarkGray
    Invoke-WtaReadOnlyScan -Context $context -SampleSeconds $SampleSeconds | Out-Null
    Invoke-WtaRuleEngine -Context $context | Out-Null
    Export-WtaReports -Context $context

    Show-WtaAssessment -Context $context

    $items = Get-WtaActionPickerItems -Context $context
    $selected = Get-WtaActionPicker -Context $context -Items $items
    if ($selected.Count -gt 0) {
        Invoke-WtaSelectedActions -Context $context -Selected $selected
        Export-WtaReports -Context $context
    }

    if ([bool]$settings.Telemetry.Enabled) {
        Invoke-WtaTelemetryUpload -Context $context
        Invoke-WtaFeedbackPrompt -Context $context
        Export-WtaReports -Context $context
    }
}
catch {
    if ($outputRoot) {
        try { $_ | Out-String | Set-Content -LiteralPath (Join-Path $outputRoot 'FatalError.txt') -Encoding UTF8 } catch {}
    }
    Write-Host ("Unexpected non-recoverable host error: {0}" -f $_.Exception.Message) -ForegroundColor Red
}
finally {
    if ($null -ne $context) { try { Export-WtaReports -Context $context } catch {} }
    Write-Host ''
    if ($outputRoot) { Write-Host ("Session folder: {0}" -f $outputRoot) -ForegroundColor DarkGray }
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
