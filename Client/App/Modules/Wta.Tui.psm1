
# Wta.Tui.psm1
Import-Module (Join-Path $PSScriptRoot 'Wta.Common.psm1') -DisableNameChecking

function Write-WtaPanelHeader {
    param([Parameter(Mandatory)][string]$Title,[string]$Subtitle = '')
    Write-Host ''
    Write-Host '  +----------------------------------------------------------------+' -ForegroundColor DarkMagenta
    Write-Host ("  | {0}" -f $Title.PadRight(62)) -ForegroundColor Cyan
    if ($Subtitle) { Write-Host ("  | {0}" -f $Subtitle.PadRight(62)) -ForegroundColor DarkGray }
    Write-Host '  +----------------------------------------------------------------+' -ForegroundColor DarkMagenta
}

function Write-WtaBanner {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    Clear-Host
    Write-WtaPanelHeader -Title 'WIN TUNE ADVISOR' -Subtitle ("v{0} | {1} | local-first diagnostic CLI" -f $Context.ProductVersion, $Context.Channel)
}

function Write-WtaPhaseProgress {
    param(
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][int]$Percent,
        [int]$Id = 1
    )

    $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
    Write-Progress -Id $Id -Activity $Activity -Status $Status -PercentComplete $safePercent
}

function Complete-WtaProgress {
    param([int]$Id = 1)
    Write-Progress -Id $Id -Activity 'WinTune Advisor' -Completed
}

function Write-WtaCollectorStatus {
    param([Parameter(Mandatory)][pscustomobject]$Operation)

    $symbol = switch ($Operation.Status) {
        'Success'        { '+' }
        'Degraded'       { '~' }
        'Skipped'        { '-' }
        'FailedNonFatal' { '!' }
        default          { '?' }
    }

    $color = switch ($Operation.Status) {
        'Success'        { 'Green' }
        'Degraded'       { 'Yellow' }
        'Skipped'        { 'DarkGray' }
        'FailedNonFatal' { 'Red' }
        default          { 'Gray' }
    }

    $detail = if ($Operation.ErrorCode) { " - $($Operation.ErrorCode)" } else { '' }
    Write-Host ("  [{0}] {1}{2}" -f $symbol, $Operation.Id, $detail) -ForegroundColor $color
}

function Test-WtaInteractiveTerminal {
    param([Parameter(Mandatory)][pscustomobject]$Context)
    return [bool]$Context.Capabilities.RawInput
}

function Get-WtaActionPicker {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][object[]]$Items
    )

    if ($Items.Count -eq 0) { return @() }

    # Windows Console hosts can repeat a held Space key. That made a visual
    # checkbox selector toggle twice and required a full Clear-Host redraw.
    # The numbered multi-select below is deterministic on Windows PowerShell
    # 5.1, PowerShell 7, Windows Terminal, and redirected console hosts.
    $useInteractivePicker = $false
    if (-not $useInteractivePicker -or -not (Test-WtaInteractiveTerminal -Context $Context)) {
        return Get-WtaActionPickerFallback -Context $Context -Items $Items
    }

    $cursor = 0
    $selected = @{}
    $running = $true

    while ($running) {
        Clear-Host
        Write-WtaPanelHeader -Title 'CHOOSE ACTIONS' -Subtitle 'Up/Down: move | Space: select | Enter: review | Esc: cancel'
        Write-Host ''

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $pointer = if ($i -eq $cursor) { '>' } else { ' ' }
            $mark = if ($selected.ContainsKey($item.Id) -and $selected[$item.Id]) { 'x' } else { ' ' }
            $state = if ($item.Eligible) { '' } else { " [$($item.BlockReason)]" }
            $recommend = if ($item.Recommended) { ' [recommended]' } else { '' }
            $line = ("  {0} [{1}] {2}{3}{4}" -f $pointer, $mark, $item.Name, $recommend, $state)
            $color = if ($item.Eligible) { 'Gray' } else { 'DarkGray' }
            Write-Host $line -ForegroundColor $color
            Write-Host ("          {0}" -f $item.Description) -ForegroundColor DarkGray
        }

        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 { if ($cursor -gt 0) { $cursor-- } }
            40 { if ($cursor -lt ($Items.Count - 1)) { $cursor++ } }
            32 {
                $item = $Items[$cursor]
                if ($item.Eligible) {
                    $selected[$item.Id] = -not ($selected.ContainsKey($item.Id) -and $selected[$item.Id])
                }
            }
            13 { $running = $false }
            27 { return @() }
            default {}
        }
    }

    $result = @()
    foreach ($item in $Items) {
        if ($selected.ContainsKey($item.Id) -and $selected[$item.Id]) { $result += $item }
    }
    return $result
}

function Get-WtaActionPickerFallback {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][object[]]$Items
    )

    Write-WtaPanelHeader -Title 'CHOOSE ACTIONS' -Subtitle 'Enter one or more ready action numbers, separated by commas.'
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        if ($item.Eligible) {
            Write-Host ("  [{0}] READY    {1}" -f ($i + 1), $item.Name) -ForegroundColor Green
        }
        else {
            Write-Host ("  [{0}] BLOCKED  {1}" -f ($i + 1), $item.Name) -ForegroundColor DarkGray
            Write-Host ("               {0}" -f $item.BlockReason) -ForegroundColor DarkGray
        }
        Write-Host ("               {0}" -f $item.Description) -ForegroundColor DarkGray
    }

    Write-Host ''
    $raw = Read-Host 'Choose ready actions (example: 1,3). Press Enter to cancel'
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }

    $numbers = @()
    foreach ($part in $raw.Split(',')) {
        $n = 0
        if ([int]::TryParse($part.Trim(), [ref]$n)) { $numbers += $n }
    }

    $result = @()
    foreach ($n in ($numbers | Select-Object -Unique)) {
        if ($n -ge 1 -and $n -le $Items.Count -and $Items[$n - 1].Eligible) {
            $result += $Items[$n - 1]
        }
    }
    return $result
}

function Confirm-WtaSelectedActions {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][object[]]$Actions
    )

    if ($Actions.Count -eq 0) {
        Write-Host 'No action selected. Nothing will be changed.' -ForegroundColor DarkGray
        return $false
    }

    Clear-Host
    Write-WtaPanelHeader -Title 'REVIEW SELECTED ACTIONS' -Subtitle 'Changes run only after the exact START confirmation.'
    foreach ($action in $Actions) {
        Write-Host ("  [x] {0}" -f $action.Name) -ForegroundColor Gray
        Write-Host ("      Risk: {0}" -f $action.Risk) -ForegroundColor DarkGray
        Write-Host ("      {0}" -f $action.Description) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  Type START exactly to execute the selected actions.' -ForegroundColor Yellow
    Write-Host '  Any other input returns without changing the system.' -ForegroundColor DarkGray

    $confirmation = Read-Host 'Confirmation'
    return ($confirmation -ceq 'START')
}

function Show-WtaAssessment {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    Clear-Host
    Write-WtaPanelHeader -Title 'ASSESSMENT SUMMARY' -Subtitle ("Safety: {0} | Admin: {1}" -f $Context.WorkStatus, $Context.IsAdministrator)
    Write-Host ''

    if ($Context.Findings.Count -eq 0) {
        Write-Host '  No rule-based finding was generated in this sampling window.' -ForegroundColor Green
    }
    else {
        foreach ($severity in @('Critical', 'Warning', 'Info', 'Optional')) {
            $group = @($Context.Findings | Where-Object { $_.Severity -eq $severity })
            if ($group.Count -eq 0) { continue }

            $color = switch ($severity) {
                'Critical' { 'Red' }
                'Warning' { 'Yellow' }
                'Info' { 'Cyan' }
                default { 'DarkGray' }
            }

            Write-Host ("  {0} ({1})" -f $severity.ToUpperInvariant(), $group.Count) -ForegroundColor $color
            foreach ($finding in $group) {
                Write-Host ("    [{0}] {1}" -f $finding.Id, $finding.Title)
                Write-Host ("          {0}" -f $finding.Evidence) -ForegroundColor DarkGray
                Write-Host ("          -> {0}" -f $finding.Recommendation) -ForegroundColor DarkGray
            }
            Write-Host ''
        }
    }

    Write-Host ("  Local report: {0}" -f (Join-Path $Context.OutputRoot 'Report.html')) -ForegroundColor DarkGray
    [void](Read-Host 'Press Enter to continue')
}

Export-ModuleMember -Function @(
    'Write-WtaBanner',
    'Write-WtaPhaseProgress',
    'Complete-WtaProgress',
    'Write-WtaCollectorStatus',
    'Test-WtaInteractiveTerminal',
    'Get-WtaActionPicker',
    'Confirm-WtaSelectedActions',
    'Show-WtaAssessment'
)
