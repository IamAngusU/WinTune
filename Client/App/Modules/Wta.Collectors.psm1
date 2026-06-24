
# Wta.Collectors.psm1
Import-Module (Join-Path $PSScriptRoot 'Wta.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Wta.Tui.psm1') -Force

function Get-WtaSystemProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'system.profile' -Capability 'Cim' -Primary {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
        $batteries = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        $pagefiles = @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)

        $lastBoot = $null
        try {
            if ($os.LastBootUpTime -is [datetime]) {
                $lastBoot = [datetime]$os.LastBootUpTime
            }
            else {
                $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime([string]$os.LastBootUpTime)
            }
        }
        catch {}

        $powerPlan = 'Unavailable'
        try { $powerPlan = (& powercfg /getactivescheme 2>&1 | Out-String).Trim() } catch {}

        [pscustomobject]@{
            OS = $os.Caption
            Version = $os.Version
            Build = $os.BuildNumber
            Model = $computer.Model
            Manufacturer = $computer.Manufacturer
            Cpu = (($cpu | ForEach-Object { $_.Name.Trim() }) -join '; ')
            PhysicalMemoryGB = [math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 1)
            UptimeHours = if ($lastBoot) { [math]::Round(((Get-Date) - $lastBoot).TotalHours, 1) } else { $null }
            HasBattery = ($batteries.Count -gt 0)
            ActivePowerPlan = $powerPlan
            PageFiles = @($pagefiles | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage)
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            Culture = [Globalization.CultureInfo]::CurrentCulture.Name
        }
    }
}

function Get-WtaVolumeProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'storage.volumes' -Primary {
        $items = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter })
        $out = @()
        foreach ($item in $items) {
            $size = [double]$item.Size
            $free = [double]$item.SizeRemaining
            $out += [pscustomobject]@{
                Drive = "$($item.DriveLetter):"
                Label = $item.FileSystemLabel
                FileSystem = $item.FileSystem
                SizeGB = [math]::Round($size / 1GB, 1)
                FreeGB = [math]::Round($free / 1GB, 1)
                FreePercent = if ($size -gt 0) { [math]::Round(($free / $size) * 100, 1) } else { 0 }
                DriveType = $item.DriveType
                HealthStatus = $item.HealthStatus
            }
        }
        return $out
    } -Fallback {
        $items = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
        $out = @()
        foreach ($item in $items) {
            $size = [double]$item.Size
            $free = [double]$item.FreeSpace
            $out += [pscustomobject]@{
                Drive = $item.DeviceID
                Label = $item.VolumeName
                FileSystem = $item.FileSystem
                SizeGB = if ($size -gt 0) { [math]::Round($size / 1GB, 1) } else { 0 }
                FreeGB = if ($free -gt 0) { [math]::Round($free / 1GB, 1) } else { 0 }
                FreePercent = if ($size -gt 0) { [math]::Round(($free / $size) * 100, 1) } else { 0 }
                DriveType = 'Fixed'
                HealthStatus = 'Unknown'
            }
        }
        return $out
    }
}

function Get-WtaDiskProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'storage.disks' -Primary {
        $disks = @(Get-Disk -ErrorAction Stop)
        $physical = @()
        try { $physical = @(Get-PhysicalDisk -ErrorAction Stop) } catch {}

        $out = @()
        foreach ($disk in $disks) {
            $matching = $physical | Where-Object { $_.FriendlyName -eq $disk.FriendlyName } | Select-Object -First 1
            $reliability = $null
            if ($null -ne $matching -and (Test-WtaCommand -Name 'Get-StorageReliabilityCounter')) {
                try { $reliability = $matching | Get-StorageReliabilityCounter -ErrorAction Stop } catch {}
            }

            $out += [pscustomobject]@{
                Number = $disk.Number
                FriendlyName = $disk.FriendlyName
                BusType = [string]$disk.BusType
                MediaType = if ($matching) { [string]$matching.MediaType } else { 'Unknown' }
                SizeGB = [math]::Round(([double]$disk.Size / 1GB), 1)
                HealthStatus = [string]$disk.HealthStatus
                OperationalStatus = (($disk.OperationalStatus | ForEach-Object { [string]$_ }) -join ', ')
                IsBoot = [bool]$disk.IsBoot
                IsSystem = [bool]$disk.IsSystem
                TemperatureC = if ($reliability) { $reliability.Temperature } else { $null }
                Wear = if ($reliability) { $reliability.Wear } else { $null }
                PowerOnHours = if ($reliability) { $reliability.PowerOnHours } else { $null }
                ReadErrorsTotal = if ($reliability) { $reliability.ReadErrorsTotal } else { $null }
                WriteErrorsTotal = if ($reliability) { $reliability.WriteErrorsTotal } else { $null }
            }
        }
        return $out
    } -Fallback {
        $drives = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)
        $out = @()
        foreach ($drive in $drives) {
            $out += [pscustomobject]@{
                Number = $drive.Index
                FriendlyName = $drive.Model
                BusType = $drive.InterfaceType
                MediaType = $drive.MediaType
                SizeGB = if ($drive.Size) { [math]::Round(([double]$drive.Size / 1GB), 1) } else { $null }
                HealthStatus = $drive.Status
                OperationalStatus = $drive.Status
                IsBoot = $null
                IsSystem = $null
                TemperatureC = $null
                Wear = $null
                PowerOnHours = $null
                ReadErrorsTotal = $null
                WriteErrorsTotal = $null
            }
        }
        return $out
    }
}

function Get-WtaTrimProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'storage.trim' -Primary {
        $raw = (& fsutil behavior query DisableDeleteNotify 2>&1 | Out-String).Trim()
        $ntfs = $null
        if ($raw -match 'NTFS\s+DisableDeleteNotify\s*=\s*([01])') { $ntfs = [int]$Matches[1] }
        $refs = $null
        if ($raw -match 'ReFS\s+DisableDeleteNotify\s*=\s*([01])') { $refs = [int]$Matches[1] }

        [pscustomobject]@{
            NtfsDisableDeleteNotify = $ntfs
            RefsDisableDeleteNotify = $refs
            Raw = $raw
        }
    }
}

function Get-WtaServiceProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'system.services' -Primary {
        $out = @()
        foreach ($name in @('WSearch', 'SysMain')) {
            try {
                $service = Get-Service -Name $name -ErrorAction Stop
                $cim = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $name) -ErrorAction Stop
                $out += [pscustomobject]@{
                    Name = $name
                    DisplayName = $service.DisplayName
                    State = [string]$service.Status
                    StartMode = [string]$cim.StartMode
                }
            }
            catch {
                $out += [pscustomobject]@{
                    Name = $name
                    DisplayName = 'Unavailable'
                    State = 'Unavailable'
                    StartMode = 'Unavailable'
                }
            }
        }
        return $out
    }
}

function Get-WtaStartupProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'system.startup' -Primary {
        $out = @()
        $locations = @(
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Scope = 'CurrentUser' },
            @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Scope = 'LocalMachine64' },
            @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Scope = 'LocalMachine32' }
        )

        foreach ($location in $locations) {
            try {
                $props = Get-ItemProperty -LiteralPath $location.Path -ErrorAction Stop
                foreach ($property in $props.PSObject.Properties) {
                    if ($property.Name -notmatch '^PS') {
                        $out += [pscustomobject]@{
                            Name = $property.Name
                            Location = $location.Path
                            Scope = $location.Scope
                            Source = 'RegistryRun'
                            CommandPresent = (-not [string]::IsNullOrWhiteSpace([string]$property.Value))
                        }
                    }
                }
            }
            catch {}
        }

        try {
            foreach ($entry in @(Get-CimInstance Win32_StartupCommand -ErrorAction Stop)) {
                $out += [pscustomobject]@{
                    Name = $entry.Name
                    Location = $entry.Location
                    Scope = $entry.User
                    Source = 'WMI'
                    CommandPresent = (-not [string]::IsNullOrWhiteSpace([string]$entry.Command))
                }
            }
        }
        catch {}

        return @($out | Sort-Object Name, Location -Unique)
    }
}

function Get-WtaEventProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'reliability.storageEvents' -Capability 'GetWinEvent' -Primary {
        $ids = @(7, 51, 55, 129, 153, 157)
        $start = (Get-Date).AddDays(-7)
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $start } -ErrorAction Stop |
            Where-Object { $ids -contains $_.Id } |
            Select-Object -First 250)

        $summary = @()
        foreach ($group in ($events | Group-Object Id)) {
            $summary += [pscustomobject]@{
                EventId = [int]$group.Name
                Count = $group.Count
            }
        }

        [pscustomobject]@{
            WindowDays = 7
            TotalCount = $events.Count
            Summary = $summary
        }
    }
}

function Get-WtaVisualEffectsProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'ui.visualEffects' -Primary {
        $minAnimate = $null
        $visualFx = $null
        try { $minAnimate = (Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -ErrorAction Stop).MinAnimate } catch {}
        try { $visualFx = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -ErrorAction Stop).VisualFXSetting } catch {}

        [pscustomobject]@{
            MinAnimate = $minAnimate
            VisualFXSetting = $visualFx
        }
    }
}

function Get-WtaTempProfile {
    param([Parameter(Mandatory)][pscustomobject]$Context)

    return Invoke-WtaSafeOperation -Context $Context -Id 'cleanup.tempCandidates' -Primary {
        $paths = @()
        if ($env:TEMP) { $paths += $env:TEMP }
        if ($env:TMP -and $env:TMP -ne $env:TEMP) { $paths += $env:TMP }
        $paths = @($paths | Select-Object -Unique)

        $cutoff = (Get-Date).AddDays(-7)
        $bytes = [int64]0
        $count = 0
        foreach ($path in $paths) {
            if (-not (Test-Path -LiteralPath $path)) { continue }
            try {
                Get-ChildItem -LiteralPath $path -Force -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt $cutoff } |
                    ForEach-Object {
                        $bytes += [int64]$_.Length
                        $count++
                    }
            }
            catch {}
        }

        [pscustomobject]@{
            Paths = $paths
            OlderThan = $cutoff.ToString('o')
            FileCount = $count
            TotalMB = [math]::Round($bytes / 1MB, 1)
        }
    }
}

function Get-WtaPerformanceProfile {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [ValidateRange(5, 180)][int]$SampleSeconds = 20
    )

    return Invoke-WtaSafeOperation -Context $Context -Id 'performance.liveSample' -Capability 'Cim' -Primary {
        $systemRows = @()
        $diskRows = @()
        $processRows = @()

        for ($i = 1; $i -le $SampleSeconds; $i++) {
            $cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
            $memory = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop
            $diskStats = @(Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop | Where-Object { $_.Name -ne '_Total' })

            $systemRows += [pscustomobject]@{
                Sample = $i
                CpuPercent = [math]::Round([double]$cpu.PercentProcessorTime, 2)
                AvailableMemoryMB = [math]::Round([double]$memory.AvailableMBytes, 0)
                CommittedMemoryPercent = [math]::Round([double]$memory.PercentCommittedBytesInUse, 2)
                PagesPerSecond = [math]::Round([double]$memory.PagesPersec, 2)
            }

            $totalRead = [double]0
            $totalWrite = [double]0
            $maxQueue = [double]0
            foreach ($disk in $diskStats) {
                $read = [math]::Round(([double]$disk.DiskReadBytesPersec / 1MB), 3)
                $write = [math]::Round(([double]$disk.DiskWriteBytesPersec / 1MB), 3)
                $queue = [math]::Round([double]$disk.AvgDiskQueueLength, 3)
                $totalRead += $read
                $totalWrite += $write
                if ($queue -gt $maxQueue) { $maxQueue = $queue }

                $diskRows += [pscustomobject]@{
                    Sample = $i
                    Disk = $disk.Name
                    ReadMBps = $read
                    WriteMBps = $write
                    BusyPercent = [math]::Round([double]$disk.PercentDiskTime, 2)
                    QueueLength = $queue
                    ReadLatencyMs = [math]::Round(([double]$disk.AvgDisksecPerRead * 1000), 3)
                    WriteLatencyMs = [math]::Round(([double]$disk.AvgDisksecPerWrite * 1000), 3)
                }
            }

            try {
                $processes = @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
                    Where-Object { $_.Name -notin @('_Total', 'Idle') -and $_.IDProcess -gt 0 })
                foreach ($process in $processes) {
                    if ($process.IOReadBytesPersec -gt 0 -or $process.IOWriteBytesPersec -gt 0) {
                        $processRows += [pscustomobject]@{
                            ProcessName = $process.Name
                            ProcessId = [int]$process.IDProcess
                            ReadMBps = [math]::Round(([double]$process.IOReadBytesPersec / 1MB), 3)
                            WriteMBps = [math]::Round(([double]$process.IOWriteBytesPersec / 1MB), 3)
                        }
                    }
                }
            }
            catch {}

            $percent = [math]::Round(($i / $SampleSeconds) * 100, 0)
            Write-WtaPhaseProgress -Id 2 -Activity 'Live system sample' -Status ("CPU {0}% | RAM {1} MB free | Disk R {2} MB/s W {3} MB/s | Queue {4}" -f $cpu.PercentProcessorTime, $memory.AvailableMBytes, $totalRead, $totalWrite, $maxQueue) -Percent $percent
            Start-Sleep -Seconds 1
        }

        Complete-WtaProgress -Id 2

        $system = [pscustomobject]@{
            AverageCpuPercent = [math]::Round((($systemRows | Measure-Object CpuPercent -Average).Average), 2)
            PeakCpuPercent = [math]::Round((($systemRows | Measure-Object CpuPercent -Maximum).Maximum), 2)
            LowestAvailableMemoryMB = [math]::Round((($systemRows | Measure-Object AvailableMemoryMB -Minimum).Minimum), 0)
            AverageCommittedMemoryPercent = [math]::Round((($systemRows | Measure-Object CommittedMemoryPercent -Average).Average), 2)
            AveragePagesPerSecond = [math]::Round((($systemRows | Measure-Object PagesPerSecond -Average).Average), 2)
        }

        $diskSummary = @()
        foreach ($group in ($diskRows | Group-Object Disk)) {
            $diskSummary += [pscustomobject]@{
                Disk = $group.Name
                AverageReadMBps = [math]::Round((($group.Group | Measure-Object ReadMBps -Average).Average), 3)
                AverageWriteMBps = [math]::Round((($group.Group | Measure-Object WriteMBps -Average).Average), 3)
                PeakBusyPercent = [math]::Round((($group.Group | Measure-Object BusyPercent -Maximum).Maximum), 2)
                AverageQueueLength = [math]::Round((($group.Group | Measure-Object QueueLength -Average).Average), 3)
                AverageWriteLatencyMs = [math]::Round((($group.Group | Measure-Object WriteLatencyMs -Average).Average), 3)
            }
        }

        $processSummary = @()
        foreach ($group in ($processRows | Group-Object { "$($_.ProcessName) (PID $($_.ProcessId))" })) {
            $processSummary += [pscustomobject]@{
                Process = $group.Name
                AverageReadMBps = [math]::Round((($group.Group | Measure-Object ReadMBps -Average).Average), 3)
                AverageWriteMBps = [math]::Round((($group.Group | Measure-Object WriteMBps -Average).Average), 3)
                PeakWriteMBps = [math]::Round((($group.Group | Measure-Object WriteMBps -Maximum).Maximum), 3)
            }
        }

        [pscustomobject]@{
            SampleSeconds = $SampleSeconds
            System = $system
            Disks = $diskSummary
            TopProcesses = @($processSummary | Sort-Object AverageWriteMBps, AverageReadMBps -Descending | Select-Object -First 40)
            RawSystem = $systemRows
            RawDisks = $diskRows
        }
    }
}

function Invoke-WtaReadOnlyScan {
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [ValidateRange(5, 180)][int]$SampleSeconds = 20
    )

    $phase = 0
    $steps = 9

    $collectors = @(
        @{ Key = 'System'; Name = 'System profile'; Run = { Get-WtaSystemProfile -Context $Context } },
        @{ Key = 'Volumes'; Name = 'Volumes and free space'; Run = { Get-WtaVolumeProfile -Context $Context } },
        @{ Key = 'Disks'; Name = 'Disk health and transport'; Run = { Get-WtaDiskProfile -Context $Context } },
        @{ Key = 'Trim'; Name = 'TRIM state'; Run = { Get-WtaTrimProfile -Context $Context } },
        @{ Key = 'Services'; Name = 'Services'; Run = { Get-WtaServiceProfile -Context $Context } },
        @{ Key = 'Startup'; Name = 'Startup inventory'; Run = { Get-WtaStartupProfile -Context $Context } },
        @{ Key = 'Events'; Name = 'Storage reliability events'; Run = { Get-WtaEventProfile -Context $Context } },
        @{ Key = 'VisualEffects'; Name = 'Visual settings'; Run = { Get-WtaVisualEffectsProfile -Context $Context } },
        @{ Key = 'Temp'; Name = 'Temporary-file candidates'; Run = { Get-WtaTempProfile -Context $Context } }
    )

    foreach ($collector in $collectors) {
        $phase++
        $percent = [math]::Round((($phase - 1) / $steps) * 55, 0)
        Write-WtaPhaseProgress -Activity 'Live system analysis' -Status $collector.Name -Percent $percent
        $result = & $collector.Run
        $Context.Baseline[$collector.Key] = $result.Data
        Write-WtaCollectorStatus -Operation $result
    }

    Write-WtaPhaseProgress -Activity 'Live system analysis' -Status 'Live CPU, memory, disk and process I/O sample' -Percent 58
    $performance = Get-WtaPerformanceProfile -Context $Context -SampleSeconds $SampleSeconds
    $Context.Baseline['Performance'] = $performance.Data
    Write-WtaCollectorStatus -Operation $performance

    Write-WtaPhaseProgress -Activity 'Live system analysis' -Status 'Completing analysis' -Percent 92
    Complete-WtaProgress -Id 1
    return $Context
}

Export-ModuleMember -Function @(
    'Invoke-WtaReadOnlyScan'
)
