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

$release = Get-Content -LiteralPath (Join-Path $ClientRoot 'App\release.json') -Raw | ConvertFrom-Json
if ([string]$release.version -ne [string]$settings.ProductVersion) { throw 'release.json version does not match appsettings.json.' }
foreach ($entry in @($release.files)) {
    $path = Join-Path (Join-Path $ClientRoot 'App') $entry.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Release file is missing: $($entry.path)" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne [string]$entry.sha256) { throw "Release hash mismatch: $($entry.path)" }
}

foreach ($language in @('en','de')) {
    Set-WtaLanguage -Language $language
    foreach ($key in @('RecycleBinPictures','RecycleBinChoose','RecycleBinRestoreConfirm','PermanentDeletionGuidance')) {
        if ((Get-WtaText -Key $key) -eq $key) { throw "Missing $language text: $key" }
    }
}
Write-Host 'Client PowerShell smoke test passed.' -ForegroundColor Green
