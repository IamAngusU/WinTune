
# Wta.Common.psm1
# Windows PowerShell 5.1 / PowerShell 7+ compatible.

Set-StrictMode -Version 2.0

function Get-WtaLocalDataRoot {
    $root = Join-Path $env:LOCALAPPDATA 'WinTuneAdvisor'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return $root
}

function Test-WtaAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Test-WtaCommand {
    param([Parameter(Mandatory)][string]$Name)
    return ($null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue))
}

function New-WtaContext {
    param(
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][hashtable]$Settings,
        [string]$BootstrapRoot = ''
    )

    $context = [pscustomobject]@{
        ProductName     = 'WinTune Advisor'
        ProductVersion  = [string]$Settings.ProductVersion
        Channel         = [string]$Settings.Channel
        SessionId       = ([guid]::NewGuid().ToString())
        StartedAt       = (Get-Date).ToString('o')
        OutputRoot      = $OutputRoot
        BootstrapRoot   = $BootstrapRoot
        Settings        = $Settings
        IsAdministrator = (Test-WtaAdministrator)
        WorkStatus      = 'Unknown'
        ProtectMode     = $true
        Capabilities    = [ordered]@{}
        Baseline        = [ordered]@{}
        Operations      = @()
        Findings        = @()
        Decisions       = @()
        ActionResults   = @()
        Notices         = @()
    }

    $context.Capabilities = Get-WtaCapabilities -Context $context
    return $context
}

function Get-WtaCapabilities {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $rawInput = $false
    try {
        $null = $Host.UI.RawUI
        $null = $Host.UI.RawUI.KeyAvailable
        $rawInput = $true
    }
    catch {
        $rawInput = $false
    }

    return [ordered]@{
        IsAdministrator        = $Context.IsAdministrator
        RawInput               = $rawInput
        Cim                    = (Test-WtaCommand -Name 'Get-CimInstance')
        GetVolume              = (Test-WtaCommand -Name 'Get-Volume')
        GetDisk                = (Test-WtaCommand -Name 'Get-Disk')
        GetPhysicalDisk        = (Test-WtaCommand -Name 'Get-PhysicalDisk')
        StorageReliability     = (Test-WtaCommand -Name 'Get-StorageReliabilityCounter')
        OptimizeVolume         = (Test-WtaCommand -Name 'Optimize-Volume')
        GetWinEvent            = (Test-WtaCommand -Name 'Get-WinEvent')
        GetFileHash            = (Test-WtaCommand -Name 'Get-FileHash')
        InvokeWebRequest       = (Test-WtaCommand -Name 'Invoke-WebRequest')
        CanWriteLocalData      = $true
    }
}

function Add-WtaNotice {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Message
    )

    $Context.Notices += [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Kind      = $Kind
        Message   = $Message
    }
}

function Write-WtaLog {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Data = @{}
    )

    try {
        $record = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            Type      = $Type
            Message   = $Message
            Data      = $Data
        }
        $line = $record | ConvertTo-Json -Depth 8 -Compress
        Add-Content -LiteralPath (Join-Path $Context.OutputRoot 'Audit.jsonl') -Value $line -Encoding UTF8
    }
    catch {
        # Logging must never stop the scan or an action.
    }
}

function ConvertTo-WtaErrorCode {
    param([Parameter(Mandatory)][System.Exception]$Exception)

    if ($Exception -is [System.UnauthorizedAccessException]) { return 'ACCESS_DENIED' }
    if ($Exception -is [System.Management.Automation.CommandNotFoundException]) { return 'COMMAND_NOT_FOUND' }
    if ($Exception -is [System.TimeoutException]) { return 'TIMEOUT' }
    if ($Exception.Message -match 'Access is denied|Zugriff verweigert') { return 'ACCESS_DENIED' }
    if ($Exception.Message -match 'not recognized|nicht als Name') { return 'COMMAND_NOT_FOUND' }
    return 'UNEXPECTED_ERROR'
}

function Invoke-WtaSafeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][scriptblock]$Primary,
        [scriptblock]$Fallback,
        [string]$Capability = '',
        [switch]$RequiresAdministrator
    )

    $started = Get-Date
    $result = [ordered]@{
        Id           = $Id
        Status       = 'FailedNonFatal'
        Source       = 'Primary'
        FallbackUsed = $false
        ErrorCode    = $null
        ErrorMessage = $null
        Data         = $null
        DurationMs   = $null
    }

    try {
        if ($RequiresAdministrator -and -not $Context.IsAdministrator) {
            $result.Status = 'Skipped'
            $result.ErrorCode = 'ADMIN_REQUIRED'
            $result.ErrorMessage = 'Administrator rights are required for this operation.'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($Capability) -and -not [bool]$Context.Capabilities[$Capability]) {
            $result.Status = 'Skipped'
            $result.ErrorCode = 'CAPABILITY_UNAVAILABLE'
            $result.ErrorMessage = "Capability unavailable: $Capability"
        }
        else {
            $result.Data = & $Primary
            $result.Status = 'Success'
        }
    }
    catch {
        $primaryException = $_.Exception

        if ($null -ne $Fallback) {
            try {
                $result.Data = & $Fallback
                $result.Status = 'Degraded'
                $result.Source = 'Fallback'
                $result.FallbackUsed = $true
                $result.ErrorCode = 'PRIMARY_FAILED'
                $result.ErrorMessage = $primaryException.Message
            }
            catch {
                $result.Status = 'FailedNonFatal'
                $result.ErrorCode = 'PRIMARY_AND_FALLBACK_FAILED'
                $result.ErrorMessage = $_.Exception.Message
            }
        }
        else {
            $result.Status = 'FailedNonFatal'
            $result.ErrorCode = ConvertTo-WtaErrorCode -Exception $primaryException
            $result.ErrorMessage = $primaryException.Message
        }
    }
    finally {
        $result.DurationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 0)
        $operation = [pscustomobject]$result
        $Context.Operations += $operation

        Write-WtaLog -Context $Context -Type 'Operation' -Message $Id -Data @{
            Status       = $result.Status
            Source       = $result.Source
            FallbackUsed = $result.FallbackUsed
            ErrorCode    = $result.ErrorCode
            DurationMs   = $result.DurationMs
        }
    }

    return [pscustomobject]$result
}

function Get-WtaChoice {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string[]]$Allowed,
        [string]$Default = ''
    )

    while ($true) {
        $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { '' } else { " [$Default]" }
        $value = Read-Host "$Prompt$suffix"
        if ([string]::IsNullOrWhiteSpace($value) -and -not [string]::IsNullOrWhiteSpace($Default)) {
            $value = $Default
        }

        foreach ($allowedValue in $Allowed) {
            if ($value -ieq $allowedValue) { return $allowedValue }
        }

        Write-Host ("Please enter one of: {0}" -f ($Allowed -join ', ')) -ForegroundColor Yellow
    }
}

function Set-WtaWorkSafetyMode {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    Write-Host ''
    Write-Host 'WORK SAFETY MODE' -ForegroundColor Cyan
    Write-Host 'Windows cannot reliably detect unsaved work in every application.' -ForegroundColor DarkGray
    Write-Host 'Choose the safest answer. Yes or Unknown blocks all system-changing actions.' -ForegroundColor DarkGray

    $choice = Get-WtaChoice -Prompt 'Is unsaved work currently open? (Y/N/U = unknown)' -Allowed @('Y', 'N', 'U') -Default 'U'

    if ($choice -eq 'N') {
        $Context.WorkStatus = 'SavedConfirmed'
        $Context.ProtectMode = $false
    }
    elseif ($choice -eq 'Y') {
        $Context.WorkStatus = 'UnsavedWork'
        $Context.ProtectMode = $true
    }
    else {
        $Context.WorkStatus = 'Unknown'
        $Context.ProtectMode = $true
    }

    Write-WtaLog -Context $Context -Type 'SafetyGate' -Message 'Work safety state selected.' -Data @{
        WorkStatus = $Context.WorkStatus
        ProtectMode = $Context.ProtectMode
    }
}

function Get-WtaJsonFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $value = $raw | ConvertFrom-Json
    return ConvertTo-WtaHashtable -InputObject $value
}

function ConvertTo-WtaHashtable {
    param([Parameter(Mandatory)]$InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = @{}
        foreach ($key in $InputObject.Keys) {
            $hash[$key] = ConvertTo-WtaHashtable -InputObject $InputObject[$key]
        }
        return $hash
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-WtaHashtable -InputObject $item
        }
        return $items
    }

    if ($InputObject.PSObject -and $InputObject.PSObject.Properties.Count -gt 0 -and -not ($InputObject -is [string])) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-WtaHashtable -InputObject $property.Value
        }
        return $hash
    }

    return $InputObject
}

function Get-WtaSha256 {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-WtaCommand -Name 'Get-FileHash') {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    }

    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hash = $sha.ComputeHash($stream)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Export-WtaReports {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $report = [ordered]@{
        Metadata = [ordered]@{
            ProductName = $Context.ProductName
            ProductVersion = $Context.ProductVersion
            Channel = $Context.Channel
            SessionId = $Context.SessionId
            StartedAt = $Context.StartedAt
            GeneratedAt = (Get-Date).ToString('o')
            IsAdministrator = $Context.IsAdministrator
            WorkStatus = $Context.WorkStatus
            ProtectMode = $Context.ProtectMode
        }
        Capabilities = $Context.Capabilities
        Baseline = $Context.Baseline
        Operations = $Context.Operations
        Findings = $Context.Findings
        Decisions = $Context.Decisions
        ActionResults = $Context.ActionResults
        Notices = $Context.Notices
    }

    try {
        $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $Context.OutputRoot 'Report.json') -Encoding UTF8
    }
    catch {
        Add-WtaNotice -Context $Context -Kind 'ReportError' -Message $_.Exception.Message
    }

    try {
        $rows = @()
        foreach ($finding in $Context.Findings) {
            $rows += [pscustomobject]@{
                Id = $finding.Id
                Severity = $finding.Severity
                Category = $finding.Category
                RuleId = $finding.RuleId
                Title = $finding.Title
                Evidence = $finding.Evidence
                Recommendation = $finding.Recommendation
                ActionIds = ($finding.ActionIds -join ', ')
            }
        }
        if ($rows.Count -gt 0) {
            $rows | Export-Csv -LiteralPath (Join-Path $Context.OutputRoot 'Findings.csv') -NoTypeInformation -Encoding UTF8 -Delimiter ';'
        }
    }
    catch {}

    try {
        $html = New-WtaHtmlReport -Context $Context
        Set-Content -LiteralPath (Join-Path $Context.OutputRoot 'Report.html') -Value $html -Encoding UTF8
    }
    catch {
        Add-WtaNotice -Context $Context -Kind 'HtmlReportError' -Message $_.Exception.Message
    }
}

function ConvertTo-WtaHtml {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function New-WtaHtmlReport {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $findingRows = @()
    foreach ($finding in $Context.Findings) {
        $findingRows += @"
<tr>
<td>$((ConvertTo-WtaHtml $finding.Severity))</td>
<td>$((ConvertTo-WtaHtml $finding.Category))</td>
<td><strong>$((ConvertTo-WtaHtml $finding.Title))</strong><br><span>$((ConvertTo-WtaHtml $finding.Evidence))</span></td>
<td>$((ConvertTo-WtaHtml $finding.Recommendation))</td>
</tr>
"@
    }

    $operationRows = @()
    foreach ($operation in $Context.Operations) {
        $operationRows += @"
<tr><td>$((ConvertTo-WtaHtml $operation.Id))</td><td>$((ConvertTo-WtaHtml $operation.Status))</td><td>$((ConvertTo-WtaHtml $operation.Source))</td><td>$((ConvertTo-WtaHtml $operation.ErrorCode))</td></tr>
"@
    }

    $actionRows = @()
    foreach ($action in $Context.ActionResults) {
        $actionRows += @"
<tr><td>$((ConvertTo-WtaHtml $action.ActionId))</td><td>$((ConvertTo-WtaHtml $action.Status))</td><td>$((ConvertTo-WtaHtml $action.Details))</td></tr>
"@
    }

    return @"
<!doctype html>
<html><head><meta charset="utf-8"><title>WinTune Advisor Report</title>
<style>
body{margin:0;background:#f5f6f8;color:#20242a;font:15px/1.5 Segoe UI,Arial,sans-serif}
main{max-width:1200px;margin:36px auto;padding:0 24px 56px}
.card{background:#fff;border:1px solid #e2e5e9;border-radius:14px;padding:20px;margin:16px 0;box-shadow:0 8px 24px rgba(20,30,40,.04)}
h1{margin:0 0 6px;font-size:30px} h2{font-size:18px;margin:0 0 12px}
small,span{color:#68717b} table{width:100%;border-collapse:collapse}
th,td{text-align:left;padding:10px;border-bottom:1px solid #edf0f2;vertical-align:top}
th{font-size:12px;letter-spacing:.05em;text-transform:uppercase;color:#68717b}
</style></head><body><main>
<h1>WinTune Advisor</h1><small>Local report · Session $((ConvertTo-WtaHtml $Context.SessionId)) · Safety $((ConvertTo-WtaHtml $Context.WorkStatus))</small>
<section class="card"><h2>Findings</h2><table><thead><tr><th>Severity</th><th>Category</th><th>Finding</th><th>Recommendation</th></tr></thead><tbody>$($findingRows -join "`n")</tbody></table></section>
<section class="card"><h2>Collector results</h2><table><thead><tr><th>Collector</th><th>Status</th><th>Source</th><th>Reason</th></tr></thead><tbody>$($operationRows -join "`n")</tbody></table></section>
<section class="card"><h2>Executed actions</h2><table><thead><tr><th>Action</th><th>Status</th><th>Details</th></tr></thead><tbody>$($actionRows -join "`n")</tbody></table></section>
</main></body></html>
"@
}

Export-ModuleMember -Function @(
    'Get-WtaLocalDataRoot',
    'Test-WtaAdministrator',
    'Test-WtaCommand',
    'New-WtaContext',
    'Get-WtaCapabilities',
    'Add-WtaNotice',
    'Write-WtaLog',
    'ConvertTo-WtaErrorCode',
    'Invoke-WtaSafeOperation',
    'Get-WtaChoice',
    'Set-WtaWorkSafetyMode',
    'Get-WtaJsonFile',
    'ConvertTo-WtaHashtable',
    'Get-WtaSha256',
    'Export-WtaReports',
    'ConvertTo-WtaHtml',
    'New-WtaHtmlReport'
)
