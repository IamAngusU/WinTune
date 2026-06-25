
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$BootstrapRoot = '',
    [ValidateSet('en','de')][string]$Language = 'en',
    [ValidateRange(5,180)][int]$SampleSeconds = 20,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    Write-Host 'WinTune Advisor supports Windows only. / WinTune Advisor unterstützt nur Windows.' -ForegroundColor Red
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
    try {
        New-Item -ItemType Directory -Path $outputRoot -Force -ErrorAction Stop | Out-Null
    }
    catch {
        $desktop = Join-Path $env:LOCALAPPDATA 'WinTuneAdvisor\reports'
        $outputRoot = Join-Path $desktop ("WinTuneAdvisor_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        New-Item -ItemType Directory -Path $outputRoot -Force -ErrorAction Stop | Out-Null
    }
    $context = New-WtaContext -OutputRoot $outputRoot -Settings $settings -BootstrapRoot $BootstrapRoot -Language $Language

    Write-WtaBanner -Context $context
    Flush-WtaFunnelQueue -Context $context
    Send-WtaFunnelEvent -Context $context -EventName 'app_started'
    Write-Host (Get-WtaText -Key 'AnalysisNotice') -ForegroundColor DarkGray
    if ($context.IsAdministrator) {
        Write-Host (Get-WtaText -Key 'AdminDetected') -ForegroundColor Green
    } else {
        Write-Host (Get-WtaText -Key 'StandardDetected') -ForegroundColor Yellow
        Write-Host (Get-WtaText -Key 'RunAsAdmin') -ForegroundColor Yellow
        Write-Host (Get-WtaText -Key 'ActionsMarked') -ForegroundColor DarkGray
    }

    Set-WtaWorkSafetyMode -Context $context

    Write-Host ''
    Write-Host (Get-WtaText -Key 'LiveAnalysis') -ForegroundColor Cyan
    Write-Host (Get-WtaText -Key 'ReadOnlyScan') -ForegroundColor DarkGray
    Invoke-WtaReadOnlyScan -Context $context -SampleSeconds $SampleSeconds | Out-Null
    Invoke-WtaRuleEngine -Context $context | Out-Null
    Export-WtaReports -Context $context
    Send-WtaFunnelEvent -Context $context -EventName 'scan_completed'

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
        try {
            if ($null -ne $context) {
                $errorRoot = Ensure-WtaOutputRoot -Context $context
            } else {
                New-Item -ItemType Directory -Path $outputRoot -Force -ErrorAction Stop | Out-Null
                $errorRoot = $outputRoot
            }
            $_ | Out-String | Set-Content -LiteralPath (Join-Path $errorRoot 'FatalError.txt') -Encoding UTF8
            $outputRoot = $errorRoot
        } catch {}
    }
    Write-Host (Format-WtaText -Key 'FatalError' -Args @($_.Exception.Message)) -ForegroundColor Red
}
finally {
    if ($null -ne $context) {
        try { Send-WtaFunnelEvent -Context $context -EventName 'app_closed' } catch {}
        try { Export-WtaReports -Context $context } catch {}
    }
    Write-Host ''
    if ($outputRoot) { Write-Host (Format-WtaText -Key 'SessionFolder' -Args @($outputRoot)) -ForegroundColor DarkGray }
    if (-not $NoPause) { [void](Read-Host (Get-WtaText -Key 'PressEnterClose')) }
}
