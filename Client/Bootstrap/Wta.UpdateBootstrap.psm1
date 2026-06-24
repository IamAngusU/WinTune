
# Wta.UpdateBootstrap.psm1
# Bootstrap update logic. It never executes streamed server code.

function Get-WtaBootstrapConfig {
    param([Parameter(Mandatory)][string]$LauncherRoot)
    $path = Join-Path $LauncherRoot 'BootstrapConfig.json'
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing bootstrap config: $path" }
    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $config = @{}
    foreach ($property in $raw.PSObject.Properties) { $config[$property.Name] = $property.Value }
    return $config
}

function Get-WtaBootstrapRoot {
    $root = Join-Path $env:LOCALAPPDATA 'WinTuneAdvisor'
    foreach ($dir in @($root, (Join-Path $root 'versions'), (Join-Path $root 'downloads'), (Join-Path $root 'logs'))) {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    return $root
}

function Write-WtaBootstrapLog {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Message)
    try { Add-Content -LiteralPath (Join-Path $Root 'logs\launcher.log') -Value ("{0} {1}" -f (Get-Date).ToString('o'), $Message) -Encoding UTF8 } catch {}
}

function Get-WtaBootstrapSha256 {
    param([Parameter(Mandatory)][string]$Path)
    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    }
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $sha = [Security.Cryptography.SHA256]::Create()
        return ([BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '').ToLowerInvariant()
    } finally { if ($stream) { $stream.Dispose() } }
}

function Invoke-WtaBootstrapWeb {
    param([Parameter(Mandatory)][string]$Uri,[int]$TimeoutSeconds=3)
    $parsed = [uri]$Uri
    if ($parsed.Scheme -ne 'https') { throw 'Update endpoint must use HTTPS.' }

    $params = @{ Uri=$Uri; Method='GET'; TimeoutSec=$TimeoutSeconds; ErrorAction='Stop' }
    if ($PSVersionTable.PSVersion.Major -lt 6) { $params['UseBasicParsing'] = $true }
    return Invoke-WebRequest @params
}

function Get-WtaCertificateRsa {
    param([Parameter(Mandatory)][string]$CertificatePath)
    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
    try {
        $rsa = $cert.GetRSAPublicKey()
        if ($rsa) { return $rsa }
    } catch {}
    return $cert.PublicKey.Key
}

function Test-WtaManifestEnvelope {
    param(
        [Parameter(Mandatory)][string]$EnvelopeJson,
        [Parameter(Mandatory)][string]$CertificatePath
    )

    if (-not (Test-Path -LiteralPath $CertificatePath)) { throw "Update certificate not found: $CertificatePath" }
    $envelope = $EnvelopeJson | ConvertFrom-Json
    if (-not $envelope.payloadBase64 -or -not $envelope.signatureBase64 -or $envelope.algorithm -ne 'RSA-SHA256') {
        throw 'Malformed update manifest envelope.'
    }

    $payloadBytes = [Convert]::FromBase64String([string]$envelope.payloadBase64)
    $signatureBytes = [Convert]::FromBase64String([string]$envelope.signatureBase64)
    $rsa = Get-WtaCertificateRsa -CertificatePath $CertificatePath
    $valid = $rsa.VerifyData($payloadBytes, [Security.Cryptography.SHA256]::Create(), $signatureBytes)
    if (-not $valid) { throw 'Update manifest signature verification failed.' }

    return ([Text.Encoding]::UTF8.GetString($payloadBytes) | ConvertFrom-Json)
}

function Test-WtaVersionGreater {
    param([Parameter(Mandatory)][string]$Candidate,[Parameter(Mandatory)][string]$Current)
    try { return ([version]$Candidate -gt [version]$Current) } catch { return $false }
}

function Ensure-WtaInitialVersion {
    param(
        [Parameter(Mandatory)][string]$LauncherRoot,
        [Parameter(Mandatory)][string]$DataRoot,
        [Parameter(Mandatory)][hashtable]$Config
    )

    $currentPath = Join-Path $DataRoot 'current.json'
    if (Test-Path -LiteralPath $currentPath) { return }

    $version = [string]$Config.InitialVersion
    $source = Join-Path $LauncherRoot 'App'
    $destination = Join-Path (Join-Path $DataRoot 'versions') $version
    if (-not (Test-Path -LiteralPath $source)) { throw 'Bundled App folder is missing.' }

    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    @{ version=$version; path=$destination; installedAt=(Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $currentPath -Encoding UTF8
}

function Get-WtaCurrentVersionRecord {
    param([Parameter(Mandatory)][string]$DataRoot)
    return (Get-Content -LiteralPath (Join-Path $DataRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Expand-WtaPackage {
    param([Parameter(Mandatory)][string]$ZipPath,[Parameter(Mandatory)][string]$Destination)
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
    }
    catch {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
    }
}

function Test-WtaReleaseTree {
    param([Parameter(Mandatory)][string]$VersionPath)
    $releasePath = Join-Path $VersionPath 'release.json'
    if (-not (Test-Path -LiteralPath $releasePath)) { throw 'Release metadata missing in update package.' }
    $release = Get-Content -LiteralPath $releasePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($file in $release.files) {
        $relative = [string]$file.path
        if ($relative -match '(^|[\\/])\.\.([\\/]|$)') { throw 'Invalid release path.' }
        $full = Join-Path $VersionPath $relative
        if (-not (Test-Path -LiteralPath $full)) { throw "Release file missing: $relative" }
        $actual = Get-WtaBootstrapSha256 -Path $full
        if ($actual -ne ([string]$file.sha256).ToLowerInvariant()) { throw "Release hash mismatch: $relative" }
    }
    return $release
}

function Install-WtaUpdate {
    param(
        [Parameter(Mandatory)][string]$DataRoot,
        [Parameter(Mandatory)]$Manifest
    )

    $downloads = Join-Path $DataRoot 'downloads'
    $target = Join-Path (Join-Path $DataRoot 'versions') ([string]$Manifest.version)
    $zipPath = Join-Path $downloads ("wintune-{0}.zip" -f $Manifest.version)
    $tempPath = "$target.staging"

    $packageUri = [uri][string]$Manifest.packageUrl
    if ($packageUri.Scheme -ne 'https') { throw 'Update package URL must use HTTPS.' }
    $downloadParams = @{ Uri=[string]$Manifest.packageUrl; OutFile=$zipPath; TimeoutSec=30; ErrorAction='Stop' }
    if ($PSVersionTable.PSVersion.Major -lt 6) { $downloadParams['UseBasicParsing'] = $true }
    Invoke-WebRequest @downloadParams | Out-Null

    $actual = Get-WtaBootstrapSha256 -Path $zipPath
    if ($actual -ne ([string]$Manifest.packageSha256).ToLowerInvariant()) { throw 'Package SHA-256 mismatch.' }

    Expand-WtaPackage -ZipPath $zipPath -Destination $tempPath
    [void](Test-WtaReleaseTree -VersionPath $tempPath)

    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Move-Item -LiteralPath $tempPath -Destination $target -Force

    @{ version=[string]$Manifest.version; path=$target; installedAt=(Get-Date).ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $DataRoot 'current.json') -Encoding UTF8
    return $target
}

Export-ModuleMember -Function @(
    'Get-WtaBootstrapConfig','Get-WtaBootstrapRoot','Write-WtaBootstrapLog',
    'Invoke-WtaBootstrapWeb','Test-WtaManifestEnvelope','Test-WtaVersionGreater',
    'Ensure-WtaInitialVersion','Get-WtaCurrentVersionRecord','Install-WtaUpdate'
)
