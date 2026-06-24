
# Wta.Telemetry.psm1
Import-Module (Join-Path $PSScriptRoot 'Wta.Common.psm1') -Force

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

    $betaCode = Read-Host 'Optional beta enrollment code (press Enter to skip upload)'
    if ([string]::IsNullOrWhiteSpace($betaCode)) { return $null }

    $identity = Get-WtaInstallationIdentity
    try {
        $body = @{ betaCode=$betaCode; installationId=$identity.InstallationId } | ConvertTo-Json -Compress
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
        Add-WtaNotice -Context $Context -Kind 'TelemetryUnavailable' -Message 'No telemetry endpoint is configured.'
        return
    }

    Write-Host ''
    Write-Host 'OPTIONAL BETA TELEMETRY' -ForegroundColor Cyan
    Write-Host 'Only a minimized technical payload is sent: OS buckets, capability outcomes, rule IDs and action statuses.' -ForegroundColor DarkGray
    Write-Host 'No file paths, usernames, computer names, process command lines, event messages, serials or IP addresses are included.' -ForegroundColor DarkGray

    $choice = Get-WtaChoice -Prompt 'Send anonymized beta diagnostics now? (Y/N)' -Allowed @('Y','N') -Default 'N'
    if ($choice -ne 'Y') {
        $Context.Decisions += [pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); ActionId='Telemetry'; Decision='Declined' }
        return
    }

    $payload = New-WtaTelemetryPayload -Context $Context
    $preview = $payload | ConvertTo-Json -Depth 16
    $previewPath = Join-Path $Context.OutputRoot 'TelemetryPreview.json'
    Set-Content -LiteralPath $previewPath -Value $preview -Encoding UTF8
    Write-Host ("Payload preview saved locally: {0}" -f $previewPath) -ForegroundColor DarkGray

    $token = Get-WtaTelemetryToken -Context $Context
    if (-not $token) {
        $queued = Save-WtaTelemetryQueue -Context $Context -Payload $payload -Reason 'No enrollment token or enrollment unavailable.'
        Add-WtaNotice -Context $Context -Kind 'TelemetryQueued' -Message ("Upload not sent. Local queue: {0}" -f $queued)
        return
    }

    try {
        $body = $payload | ConvertTo-Json -Depth 16 -Compress
        $result = Invoke-WtaJsonRequest -Uri $endpoint -Method 'POST' -Body $body -Headers @{ Authorization = "Bearer $token" } -TimeoutSeconds 8
        $Context.Decisions += [pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); ActionId='Telemetry'; Decision='Uploaded' }
        Write-Host ("Telemetry uploaded. Server session: {0}" -f $result.sessionId) -ForegroundColor Green
    }
    catch {
        $queued = Save-WtaTelemetryQueue -Context $Context -Payload $payload -Reason $_.Exception.Message
        Add-WtaNotice -Context $Context -Kind 'TelemetryQueued' -Message ("Upload failed; payload queued locally: {0}" -f $queued)
        Write-Host 'Upload failed; local scan/report remain valid. The payload was queued locally.' -ForegroundColor Yellow
    }
}


function Invoke-WtaFeedbackPrompt {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $endpoint = [string]$Context.Settings.Telemetry.FeedbackEndpoint
    if ([string]::IsNullOrWhiteSpace($endpoint)) { return }

    $token = Get-WtaStoredToken
    if (-not $token) { return }

    Write-Host ''
    $scoreRaw = Read-Host 'Optional: was this diagnosis helpful? 1-5, or press Enter to skip'
    if ([string]::IsNullOrWhiteSpace($scoreRaw)) { return }
    $score = 0
    if (-not [int]::TryParse($scoreRaw, [ref]$score) -or $score -lt 1 -or $score -gt 5) {
        Write-Host 'Feedback skipped: score must be 1 to 5.' -ForegroundColor DarkGray
        return
    }

    $helpedChoice = Get-WtaChoice -Prompt 'Did it help you understand what to do? (Y/N)' -Allowed @('Y','N') -Default 'Y'
    $body = @{ sessionId=$Context.SessionId; score=$score; helped=($helpedChoice -eq 'Y') } | ConvertTo-Json -Compress
    try {
        [void](Invoke-WtaJsonRequest -Uri $endpoint -Method 'POST' -Body $body -Headers @{ Authorization = "Bearer $token" } -TimeoutSeconds 8)
        Write-Host 'Feedback sent.' -ForegroundColor Green
    }
    catch {
        Add-WtaNotice -Context $Context -Kind 'FeedbackUploadFailed' -Message $_.Exception.Message
        Write-Host 'Feedback was not sent; local report remains valid.' -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function @('Invoke-WtaTelemetryUpload','Invoke-WtaFeedbackPrompt')
