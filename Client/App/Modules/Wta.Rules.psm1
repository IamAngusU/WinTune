
# Wta.Rules.psm1
Import-Module (Join-Path $PSScriptRoot 'Wta.Common.psm1') -DisableNameChecking

function Add-WtaFinding {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][ValidateSet('Critical','Warning','Info','Optional')][string]$Severity,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$RuleId,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Evidence,
        [Parameter(Mandatory)][string]$Recommendation,
        [string[]]$ActionIds = @(),
        [ValidateSet('ReadOnly','Low','Medium','Manual')][string]$Risk = 'ReadOnly'
    )

    if ((Get-WtaLanguage) -eq 'de') {
        switch ($RuleId) {
            'STORAGE_CRITICAL_FREE_SPACE' { $Title = $Title -replace ' has critically low free space',' hat kritisch wenig freien Speicher'; $Recommendation = 'Nicht-Systemdaten verschieben oder entfernen. Windows, Programme, Projektordner oder die Auslagerungsdatei nicht automatisch verschieben.'; $Category='Speicher' }
            'STORAGE_LOW_FREE_SPACE' { $Title = $Title -replace ' has low free space',' hat wenig freien Speicher'; $Recommendation = 'Speicherplatz freigeben oder große persönliche/Projekt-Daten verschieben. Ziel: mindestens 10%, besser 15%, frei auf dem Systemvolume.'; $Category='Speicher' }
            'TRIM_DISABLED' { $Title = 'NTFS TRIM ist deaktiviert'; $Recommendation = 'NTFS TRIM aktivieren und ReTrim erst ausführen, wenn aktuelle schreibintensive Arbeit abgeschlossen ist.'; $Category='Speicher' }
            'DISK_HEALTH_NOT_HEALTHY' { $Title = $Title -replace '^Disk ','Datenträger ' -replace ' reports health status ',' meldet Gesundheitsstatus '; $Recommendation = 'Wichtige Daten sichern und Speicherhardware, Verbindung, Firmware sowie Herstellerdiagnose prüfen.'; $Category='Speicher' }
            'DISK_RELIABILITY_ERRORS' { $Title = $Title -replace '^Disk ','Datenträger ' -replace ' exposes reliability error counters',' zeigt Zuverlässigkeits-Fehlerzähler'; $Recommendation = 'Backup-Abdeckung und Herstellerdiagnose prüfen. Dieses Tool setzt Zuverlässigkeitszähler nie zurück.'; $Category='Speicher' }
            'DISK_HIGH_TEMPERATURE' { $Title = $Title -replace '^Disk ','Datenträger ' -replace ' reports high temperature',' meldet hohe Temperatur'; $Recommendation = 'Luftstrom, Kühlkörperkontakt, Firmware und dauerhafte Last prüfen, bevor schreibintensive Arbeit fortgesetzt wird.'; $Category='Speicher' }
            'STORAGE_RELIABILITY_EVENTS' { $Title = 'Aktuelle speicherbezogene Systemereignisse gefunden'; $Recommendation = 'Vor Reparaturaktionen den lokalen Bericht prüfen. Wiederholte Reset- oder I/O-Ereignisse können auf Treiber-, Controller-, Strom- oder Speicherprobleme hinweisen.'; $Category='Zuverlässigkeit' }
            'CPU_SATURATION' { $Title = 'CPU-Auslastung während der Messung beobachtet'; $Recommendation = 'Top-Prozess-I/O-Bericht und Task-Manager nutzen, um die Last mit aktueller Arbeit abzugleichen, bevor Hintergrunddienste geändert werden.' }
            'MEMORY_PRESSURE' { $Title = 'Speicherdruck während der Messung beobachtet'; $Recommendation = 'Gleichzeitige Last reduzieren oder unnötige Programme schließen. Die Auslagerungsdatei nicht pauschal als Optimierung deaktivieren.'; $Category='Arbeitsspeicher' }
            'STORAGE_IO_PRESSURE' { $Title = $Title -replace '^Storage pressure was observed on','Speicherdruck beobachtet auf'; $Recommendation = 'Den aktiv schreibenden Prozess identifizieren. Speicherwartung vermeiden, solange diese Last läuft.'; $Category='Speicher' }
            'SEARCH_INDEXER_IO' { $Title = 'Windows Search Indexer schrieb während der Messung Daten'; $Recommendation = 'Windows Search kann während schwerer Last vorübergehend pausiert und danach fortgesetzt werden.'; $Category='Hintergrundarbeit' }
            'LONG_UPTIME' { $Title = 'Lange Systemlaufzeit erkannt'; $Recommendation = 'Wenn alle Arbeit gespeichert ist, kann ein geplanter Neustart alten Zustand lösen und ausstehende Updates abschließen. Er wird nie automatisch ausgeführt.'; $Category='System' }
            'STARTUP_DENSITY' { $Title = 'Viele Autostart-Einträge entdeckt'; $Recommendation = 'Jeden Eintrag nach Zweck prüfen. Das Tool verwaltet nur unterstützte Registry-Run-Einträge und erstellt vor dem Deaktivieren ein Backup.'; $Category='Autostart' }
            'OLD_TEMP_CANDIDATES' { $Title = 'Alte TEMP-Dateien des aktuellen Benutzers gefunden'; $Recommendation = 'Optionale Bereinigung entfernt nur Dateien älter als sieben Tage aus Benutzer-TEMP-Pfaden und überspringt gesperrte Dateien.'; $Category='Bereinigung' }
            'VISUAL_EFFECTS_OPTION' { $Title = 'UI-Animationen sind eine optionale Vorliebe'; $Recommendation = 'Animationen nur reduzieren, wenn weniger UI-Bewegung gewünscht ist; das ist keine Speicherzustands-Optimierung.'; $Category='Darstellung' }
            'POWER_PLAN_OPTION' { $Title = 'Energieplan Höchstleistung ist nicht aktiv'; $Recommendation = 'Auf Desktop- oder Netzbetrieb-Workstations kann Höchstleistung die Reaktionsfähigkeit verbessern, kostet aber Energie, Wärme und Lüftergeräusch.'; $Category='Energie' }
        }
    }

    $Context.Findings += [pscustomobject]@{
        Id = ('F-{0:D3}' -f ($Context.Findings.Count + 1))
        Severity = $Severity
        Category = $Category
        RuleId = $RuleId
        Title = $Title
        Evidence = $Evidence
        Recommendation = $Recommendation
        ActionIds = $ActionIds
        Risk = $Risk
    }
}

function Invoke-WtaRuleEngine {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    $Context.Findings = @()
    $volumes = @($Context.Baseline.Volumes)
    $disks = @($Context.Baseline.Disks)
    $trim = $Context.Baseline.Trim
    $system = $Context.Baseline.System
    $events = $Context.Baseline.Events
    $performance = $Context.Baseline.Performance
    $startup = @($Context.Baseline.Startup)
    $temp = $Context.Baseline.Temp

    foreach ($volume in $volumes) {
        if ($null -eq $volume) { continue }

        if ($volume.FreePercent -lt 3) {
            Add-WtaFinding -Context $Context -Severity Critical -Category 'Storage' -RuleId 'STORAGE_CRITICAL_FREE_SPACE' `
                -Title ("{0} has critically low free space" -f $volume.Drive) `
                -Evidence ("{0} GB free of {1} GB ({2}%)." -f $volume.FreeGB, $volume.SizeGB, $volume.FreePercent) `
                -Recommendation 'Move or remove non-system data. Do not automatically move Windows, Program Files, project folders, or the pagefile.' `
                -ActionIds @('CleanUserTemp') -Risk Manual
        }
        elseif ($volume.FreePercent -lt 10) {
            Add-WtaFinding -Context $Context -Severity Warning -Category 'Storage' -RuleId 'STORAGE_LOW_FREE_SPACE' `
                -Title ("{0} has low free space" -f $volume.Drive) `
                -Evidence ("{0} GB free of {1} GB ({2}%)." -f $volume.FreeGB, $volume.SizeGB, $volume.FreePercent) `
                -Recommendation 'Free space or move large personal/project data. Target at least 10%, preferably 15%, free on the system volume.' `
                -ActionIds @('CleanUserTemp') -Risk Manual
        }
    }

    if ($trim -and $trim.NtfsDisableDeleteNotify -eq 1) {
        Add-WtaFinding -Context $Context -Severity Warning -Category 'Storage' -RuleId 'TRIM_DISABLED' `
            -Title 'NTFS TRIM is disabled' -Evidence $trim.Raw `
            -Recommendation 'Enable NTFS TRIM, then run a ReTrim only after all current write-heavy work is complete.' `
            -ActionIds @('EnableTrim','ReTrim') -Risk Low
    }

    foreach ($disk in $disks) {
        if ($null -eq $disk) { continue }

        if ($disk.HealthStatus -and $disk.HealthStatus -notmatch '^(Healthy|OK|Unknown)$') {
            Add-WtaFinding -Context $Context -Severity Critical -Category 'Storage' -RuleId 'DISK_HEALTH_NOT_HEALTHY' `
                -Title ("Disk {0} reports health status {1}" -f $disk.Number, $disk.HealthStatus) `
                -Evidence ("{0}; {1}" -f $disk.FriendlyName, $disk.OperationalStatus) `
                -Recommendation 'Back up important data and investigate storage hardware, connection, firmware, and vendor diagnostics.' `
                -ActionIds @() -Risk Manual
        }

        if (($null -ne $disk.ReadErrorsTotal -and [int64]$disk.ReadErrorsTotal -gt 0) -or ($null -ne $disk.WriteErrorsTotal -and [int64]$disk.WriteErrorsTotal -gt 0)) {
            Add-WtaFinding -Context $Context -Severity Warning -Category 'Storage' -RuleId 'DISK_RELIABILITY_ERRORS' `
                -Title ("Disk {0} exposes reliability error counters" -f $disk.Number) `
                -Evidence ("Read errors: {0}; write errors: {1}." -f $disk.ReadErrorsTotal, $disk.WriteErrorsTotal) `
                -Recommendation 'Review backup coverage and vendor diagnostics. This tool never resets reliability counters.' `
                -ActionIds @() -Risk Manual
        }

        if ($null -ne $disk.TemperatureC -and [double]$disk.TemperatureC -ge 70) {
            Add-WtaFinding -Context $Context -Severity Warning -Category 'Storage' -RuleId 'DISK_HIGH_TEMPERATURE' `
                -Title ("Disk {0} reports high temperature" -f $disk.Number) `
                -Evidence ("{0} degrees C on {1}." -f $disk.TemperatureC, $disk.FriendlyName) `
                -Recommendation 'Inspect airflow, heatsink contact, firmware, and sustained workload before continuing heavy writes.' `
                -ActionIds @() -Risk Manual
        }
    }

    if ($events -and $events.TotalCount -gt 0) {
        Add-WtaFinding -Context $Context -Severity Warning -Category 'Reliability' -RuleId 'STORAGE_RELIABILITY_EVENTS' `
            -Title 'Recent storage-related System events were found' `
            -Evidence ("{0} matching events within the last {1} days." -f $events.TotalCount, $events.WindowDays) `
            -Recommendation 'Review the local report before any repair operation. Repeated reset or I/O events may indicate drivers, controller, power, or storage issues.' `
            -ActionIds @('RunDiskScan') -Risk Medium
    }

    if ($performance -and $performance.System) {
        if ($performance.System.AverageCpuPercent -ge 90) {
            Add-WtaFinding -Context $Context -Severity Warning -Category 'CPU' -RuleId 'CPU_SATURATION' `
                -Title 'CPU saturation was observed during the sample' `
                -Evidence ("Average CPU {0}% / peak {1}%." -f $performance.System.AverageCpuPercent, $performance.System.PeakCpuPercent) `
                -Recommendation 'Use the top process I/O report and Task Manager to correlate the load with current work before changing background services.' `
                -ActionIds @() -Risk ReadOnly
        }

        if ($performance.System.AverageCommittedMemoryPercent -ge 90 -or $performance.System.LowestAvailableMemoryMB -lt 1024) {
            Add-WtaFinding -Context $Context -Severity Warning -Category 'Memory' -RuleId 'MEMORY_PRESSURE' `
                -Title 'Memory pressure was observed during the sample' `
                -Evidence ("Lowest available RAM: {0} MB; average committed memory: {1}%." -f $performance.System.LowestAvailableMemoryMB, $performance.System.AverageCommittedMemoryPercent) `
                -Recommendation 'Reduce concurrent workloads or close unnecessary programs. Do not disable the pagefile as a generic optimization.' `
                -ActionIds @() -Risk Manual
        }

        foreach ($diskPerf in @($performance.Disks)) {
            if (($diskPerf.AverageQueueLength -ge 2) -or ($diskPerf.AverageWriteLatencyMs -ge 20)) {
                Add-WtaFinding -Context $Context -Severity Warning -Category 'Storage' -RuleId 'STORAGE_IO_PRESSURE' `
                    -Title ("Storage pressure was observed on {0}" -f $diskPerf.Disk) `
                    -Evidence ("Average queue {0}; average write latency {1} ms; peak busy {2}%." -f $diskPerf.AverageQueueLength, $diskPerf.AverageWriteLatencyMs, $diskPerf.PeakBusyPercent) `
                    -Recommendation 'Identify the active writing process. Avoid storage-maintenance operations while that workload is running.' `
                    -ActionIds @() -Risk ReadOnly
            }
        }

        $indexer = @($performance.TopProcesses | Where-Object { $_.Process -match '^SearchIndexer(\.exe)?\s' })
        if ($indexer.Count -gt 0 -and $indexer[0].AverageWriteMBps -ge 2) {
            Add-WtaFinding -Context $Context -Severity Info -Category 'Background work' -RuleId 'SEARCH_INDEXER_IO' `
                -Title 'Windows Search Indexer wrote data during the sample' `
                -Evidence ("Average write throughput: {0} MB/s." -f $indexer[0].AverageWriteMBps) `
                -Recommendation 'You may pause Windows Search temporarily during a heavy workload and resume it afterward.' `
                -ActionIds @('PauseSearch') -Risk Low
        }
    }

    if ($system -and $system.UptimeHours -and $system.UptimeHours -ge 168) {
        Add-WtaFinding -Context $Context -Severity Info -Category 'System' -RuleId 'LONG_UPTIME' `
            -Title 'Long system uptime detected' -Evidence ("Uptime: {0} hours." -f $system.UptimeHours) `
            -Recommendation 'After all work is saved, a planned restart can release stale state and complete pending updates. It is never performed automatically.' `
            -ActionIds @() -Risk Manual
    }

    if ($startup.Count -gt 15) {
        Add-WtaFinding -Context $Context -Severity Info -Category 'Startup' -RuleId 'STARTUP_DENSITY' `
            -Title 'Many startup entries were discovered' -Evidence ("{0} startup entries were discovered in supported locations." -f $startup.Count) `
            -Recommendation 'Review each entry by purpose. The tool can only manage supported Registry Run entries and makes a backup before disabling one.' `
            -ActionIds @('ReviewStartup') -Risk Low
    }

    if ($temp -and $temp.TotalMB -ge 500) {
        Add-WtaFinding -Context $Context -Severity Info -Category 'Cleanup' -RuleId 'OLD_TEMP_CANDIDATES' `
            -Title 'Old current-user TEMP files were found' `
            -Evidence ("{0} files older than seven days occupy about {1} MB." -f $temp.FileCount, $temp.TotalMB) `
            -Recommendation 'Optional cleanup removes only files older than seven days from current-user TEMP paths and skips locked files.' `
            -ActionIds @('CleanUserTemp') -Risk Low
    }

    Add-WtaFinding -Context $Context -Severity Optional -Category 'Visuals' -RuleId 'VISUAL_EFFECTS_OPTION' `
        -Title 'UI animations are an optional preference' `
        -Evidence ("MinAnimate={0}; VisualFXSetting={1}." -f $Context.Baseline.VisualEffects.MinAnimate, $Context.Baseline.VisualEffects.VisualFXSetting) `
        -Recommendation 'Reduce animations only when the user prefers less UI motion; this is not a disk-health optimization.' `
        -ActionIds @('ReduceAnimations') -Risk Low

    $highPerformancePlanPattern = 'High performance|H' + [char]0x00F6 + 'chstleistung'
    if ($system -and -not $system.HasBattery -and $system.ActivePowerPlan -notmatch $highPerformancePlanPattern) {
        Add-WtaFinding -Context $Context -Severity Optional -Category 'Power' -RuleId 'POWER_PLAN_OPTION' `
            -Title 'High performance power plan is not active' -Evidence $system.ActivePowerPlan `
            -Recommendation 'On a desktop or plugged-in workstation, High performance may improve responsiveness at the cost of energy use, heat, and fan noise.' `
            -ActionIds @('HighPerformancePlan') -Risk Low
    }

    Write-WtaLog -Context $Context -Type 'RuleEngine' -Message 'Rules evaluated.' -Data @{ Findings = $Context.Findings.Count }
    return $Context.Findings
}

Export-ModuleMember -Function @('Invoke-WtaRuleEngine')
