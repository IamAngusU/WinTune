
# Wta.Actions.psm1
Import-Module (Join-Path $PSScriptRoot 'Wta.Common.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'Wta.Tui.psm1') -DisableNameChecking

function Get-WtaActionCatalog {
    if ((Get-WtaLanguage) -eq 'de') {
        return @(
            [pscustomobject]@{ Id='EnableTrim'; Name='NTFS TRIM aktivieren'; Risk='Niedrig'; RequiresAdmin=$true; RequiresSavedWork=$true; Description='Aktiviert NTFS TRIM nur, wenn der Scan es deaktiviert gefunden hat, und prüft die Einstellung danach.' },
            [pscustomobject]@{ Id='ReTrim'; Name='Ausgewählte NTFS-Volumes erneut trimmen'; Risk='Niedrig'; RequiresAdmin=$true; RequiresSavedWork=$true; Description='Sendet eine ReTrim-Anforderung an ausgewählte NTFS-Volumes. Das ist keine SSD-Defragmentierung.' },
            [pscustomobject]@{ Id='CleanUserTemp'; Name='Alte TEMP-Dateien des aktuellen Benutzers löschen'; Risk='Niedrig'; RequiresAdmin=$false; RequiresSavedWork=$true; Description='Löscht nur Dateien älter als sieben Tage in Benutzer-TEMP-Ordnern. Gesperrte Dateien werden übersprungen.' },
            [pscustomobject]@{ Id='PauseSearch'; Name='Windows Search vorübergehend pausieren'; Risk='Niedrig'; RequiresAdmin=$true; RequiresSavedWork=$false; Description='Stoppt Windows Search für die aktuelle Sitzung. Suche und Index-Aktualität sind bis zum Fortsetzen reduziert.' },
            [pscustomobject]@{ Id='ResumeSearch'; Name='Windows Search fortsetzen'; Risk='Niedrig'; RequiresAdmin=$true; RequiresSavedWork=$false; Description='Startet Windows Search, falls der Dienst gestoppt war.' },
            [pscustomobject]@{ Id='ReduceAnimations'; Name='UI-Animationen reduzieren'; Risk='Niedrig'; RequiresAdmin=$false; RequiresSavedWork=$true; Description='Reduziert Fenster-/Client-Animationen für den aktuellen Benutzer. Manche Shell-Elemente brauchen ggf. Ab- und Anmeldung.' },
            [pscustomobject]@{ Id='HighPerformancePlan'; Name='Energieplan Höchstleistung aktivieren'; Risk='Niedrig'; RequiresAdmin=$false; RequiresSavedWork=$false; Description='Aktiviert Höchstleistung und speichert das vorherige Schema zur manuellen Wiederherstellung.' },
            [pscustomobject]@{ Id='RunDiskScan'; Name='Online-Datenträgerprüfung ausführen'; Risk='Mittel'; RequiresAdmin=$true; RequiresSavedWork=$true; Description='Führt chkdsk /scan auf einem gewählten Volume aus. Das kann zusätzliche Speicher-I/O erzeugen.' },
            [pscustomobject]@{ Id='ReviewStartup'; Name='Registry-Run-Autostart-Einträge prüfen'; Risk='Niedrig'; RequiresAdmin=$false; RequiresSavedWork=$true; Description='Zeigt unterstützte Registry-Run-Einträge; beim Deaktivieren wird vorher immer ein JSON-Backup erstellt.' }
        )
    }
    return @(
        [pscustomobject]@{ Id='EnableTrim'; Name='Enable NTFS TRIM'; Risk='Low'; RequiresAdmin=$true; RequiresSavedWork=$true; Description='Enables NTFS TRIM only when the scan found it disabled, then verifies the setting.' },
        [pscustomobject]@{ Id='ReTrim'; Name='ReTrim selected NTFS volumes'; Risk='Low'; RequiresAdmin=$true; RequiresSavedWork=$true; Description='Sends a ReTrim request to selected NTFS volumes. It is not SSD defragmentation.' },
        [pscustomobject]@{ Id='CleanUserTemp'; Name='Clean old current-user TEMP files'; Risk='Low'; RequiresAdmin=$false; RequiresSavedWork=$true; Description='Deletes only files older than seven days in current-user TEMP paths. Locked files are skipped.' },
        [pscustomobject]@{ Id='PauseSearch'; Name='Pause Windows Search temporarily'; Risk='Low'; RequiresAdmin=$true; RequiresSavedWork=$false; Description='Stops Windows Search for the current session. Search and indexing freshness are reduced until resumed.' },
        [pscustomobject]@{ Id='ResumeSearch'; Name='Resume Windows Search'; Risk='Low'; RequiresAdmin=$true; RequiresSavedWork=$false; Description='Starts Windows Search if it was stopped.' },
        [pscustomobject]@{ Id='ReduceAnimations'; Name='Reduce UI animations'; Risk='Low'; RequiresAdmin=$false; RequiresSavedWork=$true; Description='Reduces window/client-area animations for the current user. Some shell elements may need sign-out.' },
        [pscustomobject]@{ Id='HighPerformancePlan'; Name='Activate High performance power plan'; Risk='Low'; RequiresAdmin=$false; RequiresSavedWork=$false; Description='Activates High performance and records the previous scheme for manual restoration.' },
        [pscustomobject]@{ Id='RunDiskScan'; Name='Run online disk scan'; Risk='Medium'; RequiresAdmin=$true; RequiresSavedWork=$true; Description='Runs chkdsk /scan on a chosen volume. It may add storage I/O.' },
        [pscustomobject]@{ Id='ReviewStartup'; Name='Review Registry Run startup entries'; Risk='Low'; RequiresAdmin=$false; RequiresSavedWork=$true; Description='Shows supported Registry Run entries; disabling one always creates a JSON backup first.' }
    )
}

function Test-WtaActionEligibility {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][pscustomobject]$Action
    )

    if ($Action.RequiresAdmin -and -not $Context.IsAdministrator) {
        return [pscustomobject]@{ Eligible=$false; Reason=(Get-WtaText -Key 'AdminRequired') }
    }
    if ($Action.RequiresSavedWork -and $Context.ProtectMode) {
        $reason = if ((Get-WtaLanguage) -eq 'de') { 'durch Arbeitsschutz-Modus blockiert' } else { 'blocked by work safety mode' }
        return [pscustomobject]@{ Eligible=$false; Reason=$reason }
    }

    if ($Action.Id -eq 'EnableTrim' -and $Context.Baseline.Trim.NtfsDisableDeleteNotify -ne 1) {
        $reason = if ((Get-WtaLanguage) -eq 'de') { 'TRIM ist bereits aktiv oder nicht verfügbar' } else { 'TRIM is already enabled or unavailable' }
        return [pscustomobject]@{ Eligible=$false; Reason=$reason }
    }

    if ($Action.Id -eq 'PauseSearch') {
        $service = @($Context.Baseline.Services | Where-Object { $_.Name -eq 'WSearch' }) | Select-Object -First 1
        if ($null -eq $service -or $service.State -ne 'Running') {
            $reason = if ((Get-WtaLanguage) -eq 'de') { 'Windows Search läuft nicht' } else { 'Windows Search is not running' }
            return [pscustomobject]@{ Eligible=$false; Reason=$reason }
        }
    }

    if ($Action.Id -eq 'ResumeSearch') {
        $service = @($Context.Baseline.Services | Where-Object { $_.Name -eq 'WSearch' }) | Select-Object -First 1
        if ($null -eq $service -or $service.State -eq 'Running') {
            $reason = if ((Get-WtaLanguage) -eq 'de') { 'Windows Search läuft bereits' } else { 'Windows Search already runs' }
            return [pscustomobject]@{ Eligible=$false; Reason=$reason }
        }
    }

    return [pscustomobject]@{ Eligible=$true; Reason='' }
}

function Get-WtaActionPickerItems {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $recommendedIds = @()
    foreach ($finding in $Context.Findings) {
        foreach ($id in $finding.ActionIds) { $recommendedIds += $id }
    }

    $items = @()
    foreach ($action in Get-WtaActionCatalog) {
        $eligibility = Test-WtaActionEligibility -Context $Context -Action $action
        $items += [pscustomobject]@{
            Id = $action.Id
            Name = $action.Name
            Description = $action.Description
            Risk = $action.Risk
            Eligible = $eligibility.Eligible
            BlockReason = $eligibility.Reason
            Recommended = ($recommendedIds -contains $action.Id)
            RequiresAdmin = $action.RequiresAdmin
            RequiresSavedWork = $action.RequiresSavedWork
        }
    }

    return $items
}

function Add-WtaActionResult {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$ActionId,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Details,
        [string]$Rollback = ''
    )

    $result = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        ActionId = $ActionId
        Status = $Status
        Details = $Details
        Rollback = $Rollback
    }
    $Context.ActionResults += $result
    Write-WtaLog -Context $Context -Type 'ActionResult' -Message $ActionId -Data @{ Status=$Status; Details=$Details; Rollback=$Rollback }
    return $result
}

function Save-WtaRollbackRecord {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$ActionId,
        [Parameter(Mandatory)][hashtable]$Data
    )

    $path = Join-Path $Context.OutputRoot ("Rollback_{0}_{1}.json" -f $ActionId, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $record = [ordered]@{ ActionId=$ActionId; CreatedAt=(Get-Date).ToString('o'); Data=$Data }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Invoke-WtaSelectedActions {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][object[]]$Selected
    )

    if (-not (Confirm-WtaSelectedActions -Context $Context -Actions $Selected)) {
        foreach ($action in $Selected) {
            $Context.Decisions += [pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); ActionId=$action.Id; Decision='DeclinedAtFinalConfirmation' }
        }
        return
    }

    foreach ($selectedAction in $Selected) {
        $catalogAction = Get-WtaActionCatalog | Where-Object { $_.Id -eq $selectedAction.Id } | Select-Object -First 1
        if ($null -eq $catalogAction) { continue }

        $eligibility = Test-WtaActionEligibility -Context $Context -Action $catalogAction
        if (-not $eligibility.Eligible) {
            Add-WtaActionResult -Context $Context -ActionId $catalogAction.Id -Status 'Skipped' -Details $eligibility.Reason | Out-Null
            continue
        }

        $Context.Decisions += [pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); ActionId=$catalogAction.Id; Decision='Accepted' }
        Write-Host ''
        Write-Host (Format-WtaText -Key 'Executing' -Args @($catalogAction.Name)) -ForegroundColor Cyan
        Invoke-WtaOneAction -Context $Context -Action $catalogAction
    }
}

function Invoke-WtaOneAction {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][pscustomobject]$Action
    )

    try {
        switch ($Action.Id) {
            'EnableTrim' {
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.enableTrim' -RequiresAdministrator -Primary {
                    & fsutil behavior set DisableDeleteNotify 0 | Out-Null
                    $verify = (& fsutil behavior query DisableDeleteNotify 2>&1 | Out-String)
                    if ($verify -notmatch 'NTFS\s+DisableDeleteNotify\s*=\s*0') { throw 'TRIM verification failed.' }
                    return $verify.Trim()
                }
                if ($result.Status -eq 'Success') {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'Success' -Details 'NTFS TRIM enabled and verified.' | Out-Null
                } else {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $result.ErrorMessage | Out-Null
                }
            }

            'ReTrim' {
                $volumes = @($Context.Baseline.Volumes | Where-Object { $_.FileSystem -eq 'NTFS' })
                $letters = @($volumes | ForEach-Object { $_.Drive.TrimEnd(':') })
                $raw = Read-Host (Format-WtaText -Key 'NtfsVolumes' -Args @($letters -join ', '))
                if ([string]::IsNullOrWhiteSpace($raw)) {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'Cancelled' -Details (Get-WtaText -Key 'NoVolume') | Out-Null
                    return
                }

                $selected = @()
                if ($raw.Trim().ToUpperInvariant() -eq 'ALL') {
                    $selected = $letters
                } else {
                    foreach ($part in $raw.Split(',')) {
                        $letter = $part.Trim().TrimEnd(':').ToUpperInvariant()
                        if ($letters -contains $letter) { $selected += $letter }
                    }
                }

                if ($selected.Count -eq 0) {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'Cancelled' -Details (Get-WtaText -Key 'NoValidVolume') | Out-Null
                    return
                }

                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.reTrim' -RequiresAdministrator -Capability 'OptimizeVolume' -Primary {
                    foreach ($letter in $selected) {
                        Optimize-Volume -DriveLetter $letter -ReTrim -Verbose -ErrorAction Stop
                    }
                    return ($selected -join ', ')
                }
                if ($result.Status -eq 'Success') {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'Success' -Details ("ReTrim completed for {0}." -f $result.Data) | Out-Null
                } else {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $result.ErrorMessage | Out-Null
                }
            }

            'CleanUserTemp' {
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.cleanUserTemp' -Primary {
                    $cutoff = (Get-Date).AddDays(-7)
                    $bytes = [int64]0
                    $deleted = 0
                    $skipped = 0
                    foreach ($path in @($Context.Baseline.Temp.Paths)) {
                        if (-not (Test-Path -LiteralPath $path)) { continue }
                        $files = @(Get-ChildItem -LiteralPath $path -Force -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff })
                        foreach ($file in $files) {
                            try {
                                $size = [int64]$file.Length
                                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                                $bytes += $size
                                $deleted++
                            }
                            catch { $skipped++ }
                        }
                    }
                    return [pscustomobject]@{ Deleted=$deleted; DeletedMB=[math]::Round($bytes/1MB,1); Skipped=$skipped }
                }
                if ($result.Status -eq 'Success') {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'Success' -Details (Format-WtaText -Key 'DeletedTemp' -Args @($result.Data.Deleted, $result.Data.DeletedMB, $result.Data.Skipped)) | Out-Null
                } else {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $result.ErrorMessage | Out-Null
                }
            }

            'PauseSearch' {
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.pauseSearch' -RequiresAdministrator -Primary {
                    Stop-Service -Name WSearch -ErrorAction Stop
                    return 'Windows Search stopped. Use Resume Windows Search to restore it.'
                }
                $details = if ($result.Data) { [string]$result.Data } else { [string]$result.ErrorMessage }
                Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $details | Out-Null
            }

            'ResumeSearch' {
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.resumeSearch' -RequiresAdministrator -Primary {
                    Start-Service -Name WSearch -ErrorAction Stop
                    return 'Windows Search started.'
                }
                $details = if ($result.Data) { [string]$result.Data } else { [string]$result.ErrorMessage }
                Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $details | Out-Null
            }

            'ReduceAnimations' {
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.reduceAnimations' -Primary {
                    $path = 'HKCU:\Control Panel\Desktop\WindowMetrics'
                    $previous = $null
                    try { $previous = (Get-ItemProperty -LiteralPath $path -Name 'MinAnimate' -ErrorAction Stop).MinAnimate } catch {}
                    $rollback = Save-WtaRollbackRecord -Context $Context -ActionId 'ReduceAnimations' -Data @{ RegistryPath=$path; Name='MinAnimate'; PreviousValue=$previous }
                    Set-ItemProperty -LiteralPath $path -Name 'MinAnimate' -Value '0' -ErrorAction Stop
                    return $rollback
                }
                $details = if ($result.Data) { 'Animations reduced.' } else { [string]$result.ErrorMessage }
                $rollback = if ($result.Data) { [string]$result.Data } else { '' }
                Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $details -Rollback $rollback | Out-Null
            }

            'HighPerformancePlan' {
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.highPerformancePlan' -Primary {
                    $before = (& powercfg /getactivescheme 2>&1 | Out-String).Trim()
                    $guid = $null
                    if ($before -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $guid = $Matches[1] }
                    $rollback = Save-WtaRollbackRecord -Context $Context -ActionId 'HighPerformancePlan' -Data @{ PreviousPowerSchemeGuid=$guid; RestoreCommand=if ($guid) { "powercfg /setactive $guid" } else { '' } }
                    & powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
                    return $rollback
                }
                $details = if ($result.Data) { 'High performance power plan activated.' } else { [string]$result.ErrorMessage }
                $rollback = if ($result.Data) { [string]$result.Data } else { '' }
                Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $details -Rollback $rollback | Out-Null
            }

            'RunDiskScan' {
                $drive = Read-Host (Get-WtaText -Key 'DrivePrompt')
                $drive = $drive.Trim().TrimEnd(':').ToUpperInvariant()
                if ($drive -notmatch '^[A-Z]$') {
                    Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'Cancelled' -Details (Get-WtaText -Key 'InvalidDrive') | Out-Null
                    return
                }
                $result = Invoke-WtaSafeOperation -Context $Context -Id 'action.diskScan' -RequiresAdministrator -Primary {
                    $output = (& chkdsk "$drive`:" /scan 2>&1 | Out-String)
                    return $output
                }
                $details = if ($result.Data) { "chkdsk /scan completed for $drive`:." } else { [string]$result.ErrorMessage }
                Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status $result.Status -Details $details | Out-Null
            }

            'ReviewStartup' {
                Invoke-WtaStartupReview -Context $Context
            }
        }
    }
    catch {
        Add-WtaActionResult -Context $Context -ActionId $Action.Id -Status 'FailedNonFatal' -Details $_.Exception.Message | Out-Null
    }
}

function Invoke-WtaStartupReview {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $items = @($Context.Baseline.Startup | Where-Object { $_.Source -eq 'RegistryRun' })
    if ($items.Count -eq 0) {
        Add-WtaActionResult -Context $Context -ActionId 'ReviewStartup' -Status 'Skipped' -Details 'No supported Registry Run startup entries found.' | Out-Null
        return
    }

    Write-Host ''
    Write-Host (Get-WtaText -Key 'StartupEntries') -ForegroundColor Cyan
    for ($i = 0; $i -lt $items.Count; $i++) {
        Write-Host ("[{0}] {1} - {2}" -f ($i + 1), $items[$i].Name, $items[$i].Location)
    }

    $raw = Read-Host (Get-WtaText -Key 'StartupChoose')
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Add-WtaActionResult -Context $Context -ActionId 'ReviewStartup' -Status 'Cancelled' -Details 'No startup item selected.' | Out-Null
        return
    }

    $index = 0
    if (-not [int]::TryParse($raw, [ref]$index) -or $index -lt 1 -or $index -gt $items.Count) {
        Add-WtaActionResult -Context $Context -ActionId 'ReviewStartup' -Status 'Cancelled' -Details 'Invalid startup selection.' | Out-Null
        return
    }

    $item = $items[$index - 1]
    $confirm = Get-WtaChoice -Prompt (Format-WtaText -Key 'StartupDisable' -Args @($item.Name)) -Allowed @('Y','N') -Default 'N'
    if ($confirm -ne 'Y') {
        Add-WtaActionResult -Context $Context -ActionId 'ReviewStartup' -Status 'Cancelled' -Details 'Startup change declined.' | Out-Null
        return
    }

    # Read the value only at execution time; it is intentionally not stored in reports or telemetry.
    try {
        $value = (Get-ItemProperty -LiteralPath $item.Location -Name $item.Name -ErrorAction Stop).$($item.Name)
        $backup = Save-WtaRollbackRecord -Context $Context -ActionId 'Startup' -Data @{ Name=$item.Name; Location=$item.Location; Value=[string]$value }
        Remove-ItemProperty -LiteralPath $item.Location -Name $item.Name -ErrorAction Stop
        Add-WtaActionResult -Context $Context -ActionId 'ReviewStartup' -Status 'Success' -Details ("Disabled '{0}'." -f $item.Name) -Rollback $backup | Out-Null
    }
    catch {
        Add-WtaActionResult -Context $Context -ActionId 'ReviewStartup' -Status 'FailedNonFatal' -Details $_.Exception.Message | Out-Null
    }
}

Export-ModuleMember -Function @(
    'Get-WtaActionPickerItems',
    'Invoke-WtaSelectedActions'
)
