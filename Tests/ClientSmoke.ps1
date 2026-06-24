#requires -Version 5.1
[CmdletBinding()]
param([string]$ClientRoot = (Join-Path $PSScriptRoot '..\Client'))

$ErrorActionPreference = 'Stop'
$files = Get-ChildItem -LiteralPath $ClientRoot -Recurse -Include *.ps1,*.psm1
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw "Parser error in $($file.FullName): $($errors[0].Message)" }
}

$common = Join-Path $ClientRoot 'App\Modules\Wta.Common.psm1'
Import-Module $common -Force -DisableNameChecking
if (-not (Get-Command Get-WtaJsonFile -ErrorAction SilentlyContinue)) { throw 'Get-WtaJsonFile was not exported.' }
$settings = Get-WtaJsonFile -Path (Join-Path $ClientRoot 'App\appsettings.json')
if (-not ($settings -is [hashtable]) -or -not $settings.ContainsKey('Telemetry')) { throw 'Settings conversion did not produce the expected hashtable.' }
Write-Host 'Client PowerShell smoke test passed.' -ForegroundColor Green
