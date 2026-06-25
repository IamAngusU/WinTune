
# Wta.Common.psm1
# Windows PowerShell 5.1 / PowerShell 7+ compatible.

Set-StrictMode -Version 2.0

$script:WtaLanguage = 'en'
$script:WtaTexts = @{
    en = @{
        AppWindowsOnly='This engine supports Windows only.'
        AnalysisNotice='After the scan, WinTune shows the analysis file locally and asks before sending it.'
        AdminDetected='Administrator session detected. Eligible elevated actions can be selected later.'
        StandardDetected='Standard-user session detected. Diagnostics and current-user actions remain available.'
        RunAsAdmin='For the full action set, close WinTune, right-click Start-WinTune.cmd, and choose "Run as administrator".'
        ActionsMarked='Nothing is blocked silently: actions that need elevation are clearly marked.'
        LiveAnalysis='LIVE ANALYSIS'
        ReadOnlyScan='The scan is read-only. A partial report is retained even when a collector is unavailable.'
        FatalError='Unexpected non-recoverable host error: {0}'
        SessionFolder='Session folder: {0}'
        PressEnterClose='Press Enter to close'
        InvalidChoice='Please enter one of: {0}'
        WorkSafetyTitle='WORK SAFETY MODE'
        WorkSafety1='Windows cannot reliably detect unsaved work in every application.'
        WorkSafety2='Choose the safest answer. Yes or Unknown blocks all system-changing actions.'
        UnsavedPrompt='Is unsaved work currently open? (Y/N/U = unknown)'
        AdminRequired='Administrator rights are required for this operation.'
        CapabilityUnavailable='Capability unavailable: {0}'
        BannerSubtitle='v{0} | {1} | local-first diagnostic CLI'
        ChooseActions='CHOOSE ACTIONS'
        ChooseActionsHelp='Enter one or more ready action numbers, separated by commas.'
        Ready='READY'
        Blocked='BLOCKED'
        ChooseReadyActions='Choose ready actions (example: 1,3). Press Enter to cancel'
        NoActionSelected='No action selected. Nothing will be changed.'
        ReviewActions='REVIEW SELECTED ACTIONS'
        ReviewActionsHelp='Changes run only after the exact START confirmation.'
        Risk='Risk: {0}'
        TypeStart='Type START exactly to execute the selected actions.'
        AnyOtherInput='Any other input returns without changing the system.'
        Confirmation='Confirmation'
        AssessmentSummary='ASSESSMENT SUMMARY'
        AssessmentSubtitle='Safety: {0} | Admin: {1}'
        NoFindings='No rule-based finding was generated in this sampling window.'
        RecommendationArrow='-> {0}'
        LocalReport='Local report: {0}'
        PressEnterContinue='Press Enter to continue'
        Executing='Executing: {0}'
        AnalysisData='ANALYSIS DATA'
        AnalysisIntro='WinTune can send minimized technical analysis so we can see where setup, updates and scans fail.'
        AnalysisIncluded='Included: Windows/version buckets, scan status, rule IDs, action statuses and capability outcomes.'
        AnalysisExcluded='Not included: file paths, usernames, computer names, process command lines, event messages, serials or raw IP addresses.'
        PreviewFile='Local preview file: {0}'
        OpenPreview='Open this analysis file in Windows Editor before deciding? (Y/N)'
        SendAnalysis='Send these analysis data now? (Y/N)'
        TelemetryUnavailable='No telemetry endpoint is configured.'
        TelemetryQueued='Upload not sent. Local queue: {0}'
        TelemetryUploaded='Telemetry uploaded. Server session: {0}'
        UploadFailed='Upload failed; local scan/report remain valid. The payload was queued locally.'
        FeedbackPrompt='Optional: was this diagnosis helpful? 1-5, or press Enter to skip'
        FeedbackInvalid='Feedback skipped: score must be 1 to 5.'
        FeedbackHelped='Did it help you understand what to do? (Y/N)'
        FeedbackSent='Feedback sent.'
        FeedbackFailed='Feedback was not sent; local report remains valid.'
        NtfsVolumes='NTFS volumes: {0}. Enter letters comma-separated or ALL'
        NoVolume='No volume selected.'
        NoValidVolume='No valid NTFS volume selected.'
        DeletedTemp='Deleted {0} files / {1} MB; skipped {2} locked/unavailable files.'
        StartupEntries='SUPPORTED REGISTRY RUN STARTUP ENTRIES'
        StartupChoose='Enter one number to disable, or press Enter to cancel'
        StartupDisable='Disable ''{0}''? Backup is created. (Y/N)'
        DrivePrompt='Drive letter for chkdsk /scan (example C)'
        InvalidDrive='Invalid drive letter.'
    }
    de = @{
        AppWindowsOnly='Diese Engine unterstützt nur Windows.'
        AnalysisNotice='Nach dem Scan zeigt WinTune die Analysedatei lokal an und fragt vor dem Senden nach.'
        AdminDetected='Administratorsitzung erkannt. Geeignete erhöhte Aktionen können später ausgewählt werden.'
        StandardDetected='Standardsitzung erkannt. Diagnosen und Benutzeraktionen bleiben verfügbar.'
        RunAsAdmin='Für alle Aktionen WinTune schließen, Start-WinTune.cmd rechtsklicken und "Als Administrator ausführen" wählen.'
        ActionsMarked='Nichts wird still blockiert: Aktionen mit Adminrechten sind klar markiert.'
        LiveAnalysis='LIVE-ANALYSE'
        ReadOnlyScan='Der Scan ist nur lesend. Ein Teilbericht bleibt erhalten, auch wenn ein Collector nicht verfügbar ist.'
        FatalError='Unerwarteter, nicht behebbarer Host-Fehler: {0}'
        SessionFolder='Sitzungsordner: {0}'
        PressEnterClose='Enter drücken zum Schließen'
        InvalidChoice='Bitte eine dieser Optionen eingeben: {0}'
        WorkSafetyTitle='ARBEITSSCHUTZ-MODUS'
        WorkSafety1='Windows kann ungespeicherte Arbeit nicht in jeder Anwendung zuverlässig erkennen.'
        WorkSafety2='Wähle die sicherste Antwort. Ja oder Unbekannt blockiert alle systemändernden Aktionen.'
        UnsavedPrompt='Ist aktuell ungespeicherte Arbeit geöffnet? (Y/N/U = unbekannt)'
        AdminRequired='Für diese Operation sind Administratorrechte erforderlich.'
        CapabilityUnavailable='Funktion nicht verfügbar: {0}'
        BannerSubtitle='v{0} | {1} | lokale Diagnose-CLI'
        ChooseActions='AKTIONEN AUSWÄHLEN'
        ChooseActionsHelp='Eine oder mehrere bereite Aktionsnummern kommagetrennt eingeben.'
        Ready='BEREIT'
        Blocked='BLOCKIERT'
        ChooseReadyActions='Bereite Aktionen wählen (Beispiel: 1,3). Enter bricht ab'
        NoActionSelected='Keine Aktion ausgewählt. Es wird nichts geändert.'
        ReviewActions='AUSGEWÄHLTE AKTIONEN PRÜFEN'
        ReviewActionsHelp='Änderungen laufen erst nach der exakten START-Bestätigung.'
        Risk='Risiko: {0}'
        TypeStart='START exakt eingeben, um die ausgewählten Aktionen auszuführen.'
        AnyOtherInput='Jede andere Eingabe kehrt zurück, ohne das System zu ändern.'
        Confirmation='Bestätigung'
        AssessmentSummary='ZUSAMMENFASSUNG'
        AssessmentSubtitle='Sicherheit: {0} | Admin: {1}'
        NoFindings='In diesem Messfenster wurde kein regelbasierter Fund erzeugt.'
        RecommendationArrow='-> {0}'
        LocalReport='Lokaler Bericht: {0}'
        PressEnterContinue='Enter drücken zum Fortfahren'
        Executing='Ausführen: {0}'
        AnalysisData='ANALYSEDATEN'
        AnalysisIntro='WinTune kann minimierte technische Analysedaten senden, damit wir sehen, wo Setup, Updates und Scans scheitern.'
        AnalysisIncluded='Enthalten: Windows-/Versions-Buckets, Scanstatus, Rule-IDs, Aktionsstatus und Fähigkeits-Ergebnisse.'
        AnalysisExcluded='Nicht enthalten: Dateipfade, Nutzernamen, Computernamen, Prozessbefehle, Eventmeldungen, Seriennummern oder rohe IP-Adressen.'
        PreviewFile='Lokale Vorschau-Datei: {0}'
        OpenPreview='Diese Analysedatei vor der Entscheidung im Windows Editor öffnen? (Y/N)'
        SendAnalysis='Diese Analysedaten jetzt senden? (Y/N)'
        TelemetryUnavailable='Kein Telemetrie-Endpunkt konfiguriert.'
        TelemetryQueued='Upload nicht gesendet. Lokale Warteschlange: {0}'
        TelemetryUploaded='Telemetrie hochgeladen. Server-Session: {0}'
        UploadFailed='Upload fehlgeschlagen; lokaler Scan/Bericht bleibt gültig. Die Daten wurden lokal vorgemerkt.'
        FeedbackPrompt='Optional: War diese Diagnose hilfreich? 1-5, oder Enter zum Überspringen'
        FeedbackInvalid='Feedback übersprungen: Wert muss 1 bis 5 sein.'
        FeedbackHelped='Hat es geholfen zu verstehen, was zu tun ist? (Y/N)'
        FeedbackSent='Feedback gesendet.'
        FeedbackFailed='Feedback wurde nicht gesendet; lokaler Bericht bleibt gültig.'
        NtfsVolumes='NTFS-Volumes: {0}. Buchstaben kommagetrennt oder ALL eingeben'
        NoVolume='Kein Volume ausgewählt.'
        NoValidVolume='Kein gültiges NTFS-Volume ausgewählt.'
        DeletedTemp='{0} Dateien / {1} MB gelöscht; {2} gesperrte/nicht verfügbare Dateien übersprungen.'
        StartupEntries='UNTERSTÜTZTE REGISTRY-RUN-AUTOSTART-EINTRÄGE'
        StartupChoose='Eine Nummer zum Deaktivieren eingeben, oder Enter zum Abbrechen'
        StartupDisable='''{0}'' deaktivieren? Backup wird erstellt. (Y/N)'
        DrivePrompt='Laufwerksbuchstabe für chkdsk /scan (Beispiel C)'
        InvalidDrive='Ungültiger Laufwerksbuchstabe.'
    }
}

function Set-WtaLanguage {
    param([ValidateSet('en','de')][string]$Language = 'en')
    $script:WtaLanguage = $Language
}

function Get-WtaLanguage {
    return $script:WtaLanguage
}

function Get-WtaText {
    param([Parameter(Mandatory)][string]$Key)
    $table = $script:WtaTexts[$script:WtaLanguage]
    if ($table.ContainsKey($Key)) { return [string]$table[$Key] }
    $fallback = $script:WtaTexts['en']
    if ($fallback.ContainsKey($Key)) { return [string]$fallback[$Key] }
    return $Key
}

function Format-WtaText {
    param([Parameter(Mandatory)][string]$Key,[object[]]$Args = @())
    return ([string]::Format((Get-WtaText -Key $Key), [object[]]$Args))
}

function Get-WtaLocalDataRoot {
    $root = Join-Path $env:LOCALAPPDATA 'WinTuneAdvisor'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return $root
}

function Ensure-WtaOutputRoot {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $target = [string]$Context.OutputRoot
    try {
        if ([string]::IsNullOrWhiteSpace($target)) { throw 'OutputRoot is empty.' }
        New-Item -ItemType Directory -Path $target -Force -ErrorAction Stop | Out-Null
        return $target
    }
    catch {
        $fallbackParent = Join-Path (Get-WtaLocalDataRoot) 'reports'
        New-Item -ItemType Directory -Path $fallbackParent -Force -ErrorAction Stop | Out-Null
        $leaf = if ([string]::IsNullOrWhiteSpace($target)) { "WinTuneAdvisor_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss') } else { Split-Path -Path $target -Leaf }
        $fallback = Join-Path $fallbackParent $leaf
        New-Item -ItemType Directory -Path $fallback -Force -ErrorAction Stop | Out-Null
        $Context.OutputRoot = $fallback
        try { Add-WtaNotice -Context $Context -Kind 'OutputRootFallback' -Message ("Report folder changed to {0}" -f $fallback) } catch {}
        return $fallback
    }
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
        [string]$BootstrapRoot = '',
        [ValidateSet('en','de')][string]$Language = 'en'
    )
    Set-WtaLanguage -Language $Language

    $context = [pscustomobject]@{
        ProductName     = 'WinTune Advisor'
        ProductVersion  = [string]$Settings.ProductVersion
        Channel         = [string]$Settings.Channel
        SessionId       = ([guid]::NewGuid().ToString())
        StartedAt       = (Get-Date).ToString('o')
        OutputRoot      = $OutputRoot
        BootstrapRoot   = $BootstrapRoot
        Language        = $Language
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
        $root = Ensure-WtaOutputRoot -Context $Context
        $record = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            Type      = $Type
            Message   = $Message
            Data      = $Data
        }
        $line = $record | ConvertTo-Json -Depth 8 -Compress
        Add-Content -LiteralPath (Join-Path $root 'Audit.jsonl') -Value $line -Encoding UTF8
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
            $result.ErrorMessage = Get-WtaText -Key 'AdminRequired'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($Capability) -and -not [bool]$Context.Capabilities[$Capability]) {
            $result.Status = 'Skipped'
            $result.ErrorCode = 'CAPABILITY_UNAVAILABLE'
            $result.ErrorMessage = Format-WtaText -Key 'CapabilityUnavailable' -Args @($Capability)
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

        Write-Host (Format-WtaText -Key 'InvalidChoice' -Args @($Allowed -join ', ')) -ForegroundColor Yellow
    }
}

function Set-WtaWorkSafetyMode {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    Write-Host ''
    Write-Host (Get-WtaText -Key 'WorkSafetyTitle') -ForegroundColor Cyan
    Write-Host (Get-WtaText -Key 'WorkSafety1') -ForegroundColor DarkGray
    Write-Host (Get-WtaText -Key 'WorkSafety2') -ForegroundColor DarkGray

    $choice = Get-WtaChoice -Prompt (Get-WtaText -Key 'UnsavedPrompt') -Allowed @('Y', 'N', 'U') -Default 'U'

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

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
        $value = $raw | ConvertFrom-Json -ErrorAction Stop
        return ConvertTo-WtaHashtable -InputObject $value
    }
    catch {
        throw "Configuration file is invalid: $Path ($($_.Exception.Message))"
    }
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

    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Count -gt 0 -and -not ($InputObject -is [string])) {
        $hash = @{}
        foreach ($property in $properties) {
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

    $root = Ensure-WtaOutputRoot -Context $Context
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
        $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $root 'Report.json') -Encoding UTF8
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
            $rows | Export-Csv -LiteralPath (Join-Path $root 'Findings.csv') -NoTypeInformation -Encoding UTF8 -Delimiter ';'
        }
    }
    catch {}

    try {
        $html = New-WtaHtmlReport -Context $Context
        Set-Content -LiteralPath (Join-Path $root 'Report.html') -Value $html -Encoding UTF8
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
<h1>WinTune Advisor</h1><small>Local report | Session $((ConvertTo-WtaHtml $Context.SessionId)) | Safety $((ConvertTo-WtaHtml $Context.WorkStatus))</small>
<section class="card"><h2>Findings</h2><table><thead><tr><th>Severity</th><th>Category</th><th>Finding</th><th>Recommendation</th></tr></thead><tbody>$($findingRows -join "`n")</tbody></table></section>
<section class="card"><h2>Collector results</h2><table><thead><tr><th>Collector</th><th>Status</th><th>Source</th><th>Reason</th></tr></thead><tbody>$($operationRows -join "`n")</tbody></table></section>
<section class="card"><h2>Executed actions</h2><table><thead><tr><th>Action</th><th>Status</th><th>Details</th></tr></thead><tbody>$($actionRows -join "`n")</tbody></table></section>
</main></body></html>
"@
}

Export-ModuleMember -Function @(
    'Get-WtaLocalDataRoot',
    'Set-WtaLanguage',
    'Get-WtaLanguage',
    'Get-WtaText',
    'Format-WtaText',
    'Ensure-WtaOutputRoot',
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
