
# Wta.Telemetry.psm1
Import-Module (Join-Path $PSScriptRoot 'Wta.Common.psm1') -DisableNameChecking

function Get-WtaTelemetryRoot {
    $root = Join-Path (Get-WtaLocalDataRoot) 'telemetry-queue'
    if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Get-WtaIdentityPath {
    return (Join-Path (Get-WtaLocalDataRoot) 'identity.json')
}

function Get-WtaInstallationIdentity {
    $path = Get-WtaIdentityPath
    try {
        if (Test-Path -LiteralPath $path) {
            return (Get-WtaJsonFile -Path $path)
        }
    }
    catch {}

    $identity = @{
        InstallationId = ([guid]::NewGuid().ToString())
        CreatedAt = (Get-Date).ToString('o')
    }
    $identity | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
    return $identity
}

function Get-WtaBucket {
    param([double]$Value, [double[]]$Thresholds)

    foreach ($threshold in $Thresholds) {
        if ($Value -lt $threshold) { return ("under-{0}" -f $threshold) }
    }
    return ("{0}-plus" -f $Thresholds[-1])
}

function New-WtaTelemetryPayload {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $identity = Get-WtaInstallationIdentity
    $system = $Context.Baseline.System
    $disks = @($Context.Baseline.Disks)

    $findings = @()
    foreach ($finding in $Context.Findings) {
        $findings += @{
            ruleId = $finding.RuleId
            severity = $finding.Severity.ToLowerInvariant()
            detected = $true
        }
    }

    $operations = @()
    foreach ($operation in $Context.Operations) {
        $operations += @{
            id = $operation.Id
            status = $operation.Status
            errorCode = $operation.ErrorCode
            fallbackUsed = [bool]$operation.FallbackUsed
        }
    }

    $actions = @()
    foreach ($action in $Context.ActionResults) {
        $actions += @{
            actionId = $action.ActionId
            status = $action.Status
        }
    }

    $storageTypes = @($disks | ForEach-Object { if ($_.BusType) { [string]$_.BusType } else { 'Unknown' } } | Select-Object -Unique)

    return [ordered]@{
        schemaVersion = '1.0'
        clientVersion = $Context.ProductVersion
        channel = $Context.Channel
        installationId = [string]$identity.InstallationId
        sessionId = $Context.SessionId
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        consent = @{ telemetry = $true }
        environment = @{
            windowsMajor = if ($system.OS -match 'Windows 11') { 11 } elseif ($system.OS -match 'Windows 10') { 10 } else { 0 }
            windowsBuild = [string]$system.Build
            powershellMajor = $PSVersionTable.PSVersion.Major
            isAdmin = [bool]$Context.IsAdministrator
            deviceType = if ($system.HasBattery) { 'laptop' } else { 'desktopOrUnknown' }
            locale = [Globalization.CultureInfo]::CurrentCulture.Name
        }
        hardware = @{
            ramGbBucket = Get-WtaBucket -Value ([double]$system.PhysicalMemoryGB) -Thresholds @(8,16,32,64,128)
            storageTypes = $storageTypes
            diskCount = $disks.Count
            batteryPresent = [bool]$system.HasBattery
        }
        scan = @{
            completed = $true
            workStatus = $Context.WorkStatus
            findingCount = $Context.Findings.Count
        }
        findings = $findings
        operations = $operations
        actions = $actions
    }
}

function Save-WtaTelemetryQueue {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)]$Payload,
        [string]$Reason = ''
    )

    try {
        $root = Get-WtaTelemetryRoot
        $path = Join-Path $root ("pending-{0}.json" -f $Context.SessionId)
        $record = [ordered]@{
            queuedAt = (Get-Date).ToString('o')
            reason = $Reason
            payload = $Payload
        }
        $record | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $path -Encoding UTF8
        return $path
    }
    catch {
        return $null
    }
}

function Invoke-WtaJsonRequest {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Method,
        [string]$Body = '',
        [hashtable]$Headers = @{},
        [int]$TimeoutSeconds = 8
    )

    $parsed = [uri]$Uri
    if ($parsed.Scheme -ne 'https') { throw 'Only HTTPS telemetry endpoints are allowed.' }

    $params = @{
        Uri = $Uri
        Method = $Method
        TimeoutSec = $TimeoutSeconds
        ErrorAction = 'Stop'
        Headers = $Headers
    }
    if (-not [string]::IsNullOrWhiteSpace($Body)) {
        $params['Body'] = $Body
        $params['ContentType'] = 'application/json'
    }
    if ($PSVersionTable.PSVersion.Major -lt 6) { $params['UseBasicParsing'] = $true }

    $response = Invoke-WebRequest @params
    if ([string]::IsNullOrWhiteSpace($response.Content)) { return @{} }
    return ConvertTo-WtaHashtable -InputObject ($response.Content | ConvertFrom-Json)
}

function Send-WtaFunnelEvent {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$EventName,
        [string]$Detail = ''
    )

    $endpoint = [string]$Context.Settings.Telemetry.FunnelEndpoint
    if ([string]::IsNullOrWhiteSpace($endpoint)) { return }
    try {
        $identity = Get-WtaInstallationIdentity
        $body = @{
            eventName = $EventName
            installationId = [string]$identity.InstallationId
            sessionId = [string]$Context.SessionId
            clientVersion = [string]$Context.ProductVersion
            channel = [string]$Context.Channel
            detail = $Detail
        } | ConvertTo-Json -Compress
        [void](Invoke-WtaJsonRequest -Uri $endpoint -Method 'POST' -Body $body -TimeoutSeconds 4)
    }
    catch {
        Add-WtaNotice -Context $Context -Kind 'FunnelEventFailed' -Message $_.Exception.Message
    }
}

function Get-WtaStoredToken {
    $identity = Get-WtaInstallationIdentity
    if (-not $identity.ContainsKey('TokenProtectedBase64')) { return $null }

    try {
        $encrypted = [Convert]::FromBase64String([string]$identity.TokenProtectedBase64)
        $bytes = [Security.Cryptography.ProtectedData]::Unprotect($encrypted, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        return $null
    }
}

function Set-WtaStoredToken {
    param([Parameter(Mandatory)][string]$Token)

    try {
        $identity = Get-WtaInstallationIdentity
        $bytes = [Text.Encoding]::UTF8.GetBytes($Token)
        $encrypted = [Security.Cryptography.ProtectedData]::Protect($bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $identity['TokenProtectedBase64'] = [Convert]::ToBase64String($encrypted)
        $identity | ConvertTo-Json | Set-Content -LiteralPath (Get-WtaIdentityPath) -Encoding UTF8
        return $true
    }
    catch {
        return $false
    }
}

function Get-WtaTelemetryToken {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $token = Get-WtaStoredToken
    if ($token) { return $token }

    $endpoint = [string]$Context.Settings.Telemetry.EnrollmentEndpoint
    if ([string]::IsNullOrWhiteSpace($endpoint)) { return $null }

    $identity = Get-WtaInstallationIdentity
    try {
        $body = @{ installationId=$identity.InstallationId } | ConvertTo-Json -Compress
        $result = Invoke-WtaJsonRequest -Uri $endpoint -Method 'POST' -Body $body -TimeoutSeconds 8
        if ($result.ContainsKey('accessToken') -and $result.accessToken) {
            [void](Set-WtaStoredToken -Token ([string]$result.accessToken))
            return [string]$result.accessToken
        }
    }
    catch {
        Add-WtaNotice -Context $Context -Kind 'TelemetryEnrollmentFailed' -Message $_.Exception.Message
    }

    return $null
}

function Invoke-WtaTelemetryUpload {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $endpoint = [string]$Context.Settings.Telemetry.EventEndpoint
    if ([string]::IsNullOrWhiteSpace($endpoint)) {
        Add-WtaNotice -Context $Context -Kind 'TelemetryUnavailable' -Message (Get-WtaText -Key 'TelemetryUnavailable')
        return
    }

    Write-Host ''
    $payload = New-WtaTelemetryPayload -Context $Context
    $preview = $payload | ConvertTo-Json -Depth 16
    $previewPath = Join-Path $Context.OutputRoot 'TelemetryPreview.json'
    Set-Content -LiteralPath $previewPath -Value $preview -Encoding UTF8

    Send-WtaFunnelEvent -Context $Context -EventName 'telemetry_prompt_shown'
    Write-Host (Get-WtaText -Key 'AnalysisData') -ForegroundColor Cyan
    Write-Host (Get-WtaText -Key 'AnalysisIntro') -ForegroundColor DarkGray
    Write-Host (Get-WtaText -Key 'AnalysisIncluded') -ForegroundColor DarkGray
    Write-Host (Get-WtaText -Key 'AnalysisExcluded') -ForegroundColor DarkGray
    Write-Host (Format-WtaText -Key 'PreviewFile' -Args @($previewPath)) -ForegroundColor DarkGray

    $openChoice = Get-WtaChoice -Prompt (Get-WtaText -Key 'OpenPreview') -Allowed @('Y','N') -Default 'Y'
    if ($openChoice -eq 'Y') {
        try { Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$previewPath`"" | Out-Null } catch {}
    }

    $choice = Get-WtaChoice -Prompt (Get-WtaText -Key 'SendAnalysis') -Allowed @('Y','N') -Default 'Y'
    if ($choice -ne 'Y') {
        $Context.Decisions += [pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); ActionId='Telemetry'; Decision='Declined' }
        Send-WtaFunnelEvent -Context $Context -EventName 'telemetry_declined'
        return
    }

    $token = Get-WtaTelemetryToken -Context $Context
    if (-not $token) {
        $queued = Save-WtaTelemetryQueue -Context $Context -Payload $payload -Reason 'No enrollment token or enrollment unavailable.'
        Add-WtaNotice -Context $Context -Kind 'TelemetryQueued' -Message (Format-WtaText -Key 'TelemetryQueued' -Args @($queued))
        Send-WtaFunnelEvent -Context $Context -EventName 'telemetry_queued' -Detail 'no-token'
        return
    }

    try {
        $body = $payload | ConvertTo-Json -Depth 16 -Compress
        $result = Invoke-WtaJsonRequest -Uri $endpoint -Method 'POST' -Body $body -Headers @{ Authorization = "Bearer $token" } -TimeoutSeconds 8
        $Context.Decisions += [pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); ActionId='Telemetry'; Decision='Uploaded' }
        Write-Host (Format-WtaText -Key 'TelemetryUploaded' -Args @($result.sessionId)) -ForegroundColor Green
        Send-WtaFunnelEvent -Context $Context -EventName 'telemetry_uploaded'
    }
    catch {
        $queued = Save-WtaTelemetryQueue -Context $Context -Payload $payload -Reason $_.Exception.Message
        Add-WtaNotice -Context $Context -Kind 'TelemetryQueued' -Message (Format-WtaText -Key 'TelemetryQueued' -Args @($queued))
        Send-WtaFunnelEvent -Context $Context -EventName 'telemetry_queued' -Detail 'upload-failed'
        Write-Host (Get-WtaText -Key 'UploadFailed') -ForegroundColor Yellow
    }
}


function Invoke-WtaFeedbackPrompt {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $endpoint = [string]$Context.Settings.Telemetry.FeedbackEndpoint
    if ([string]::IsNullOrWhiteSpace($endpoint)) { return }

    $token = Get-WtaStoredToken
    if (-not $token) { return }

    Write-Host ''
    $scoreRaw = Read-Host (Get-WtaText -Key 'FeedbackPrompt')
    if ([string]::IsNullOrWhiteSpace($scoreRaw)) { return }
    $score = 0
    if (-not [int]::TryParse($scoreRaw, [ref]$score) -or $score -lt 1 -or $score -gt 5) {
        Write-Host (Get-WtaText -Key 'FeedbackInvalid') -ForegroundColor DarkGray
        return
    }

    $helpedChoice = Get-WtaChoice -Prompt (Get-WtaText -Key 'FeedbackHelped') -Allowed @('Y','N') -Default 'Y'
    $body = @{ sessionId=$Context.SessionId; score=$score; helped=($helpedChoice -eq 'Y') } | ConvertTo-Json -Compress
    try {
        [void](Invoke-WtaJsonRequest -Uri $endpoint -Method 'POST' -Body $body -Headers @{ Authorization = "Bearer $token" } -TimeoutSeconds 8)
        Write-Host (Get-WtaText -Key 'FeedbackSent') -ForegroundColor Green
    }
    catch {
        Add-WtaNotice -Context $Context -Kind 'FeedbackUploadFailed' -Message $_.Exception.Message
        Write-Host (Get-WtaText -Key 'FeedbackFailed') -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function @('Invoke-WtaTelemetryUpload','Invoke-WtaFeedbackPrompt','Send-WtaFunnelEvent')
