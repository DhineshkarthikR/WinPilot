<#
.SYNOPSIS
    WinPilot System Specifications, Integrity & Store Health Diagnostics Module.

.DESCRIPTION
    Inspects hardware specifications, OS build, uptime, UEFI/Secure Boot environment,
    pending system reboots, and performs read-only DISM component store corruption checks.
#>

function Get-WinPilotSystemHealth {
    <#
    .SYNOPSIS
        Collects comprehensive hardware, OS, uptime, and reboot status diagnostics.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "Collecting system health and specification metrics"

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

    $totalRam = if ($os) { [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2) } else { 0 }
    $freeRam = if ($os) { [Math]::Round($os.FreePhysicalMemory / 1MB, 2) } else { 0 }

    # System Uptime
    $uptime = "Unknown"
    if ($os -and $os.LastBootUpTime) {
        $span = (Get-Date) - $os.LastBootUpTime
        $uptime = "$($span.Days)d $($span.Hours)h $($span.Minutes)m"
    }

    # Firmware and Secure Boot inspection
    $firmwareType = if (-not [string]::IsNullOrEmpty($env:firmware_type)) {
        $env:firmware_type
    } else {
        "Unknown"
    }

    $secureBootEnabled = $false
    try {
        $sbReg = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State" -ErrorAction SilentlyContinue
        if ($sbReg -and $sbReg.UEFISecureBootEnabled -eq 1) {
            $secureBootEnabled = $true
        }
    }
    catch {
        $null = $_
    }

    # Pending Reboot Inspection
    $cbsReboot = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $wuReboot = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    $pfr = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    $pendingFileRename = ($null -ne $pfr -and $null -ne $pfr.PendingFileRenameOperations)

    $isRebootPending = ($cbsReboot -or $wuReboot -or $pendingFileRename)

    return [PSCustomObject]@{
        ComputerName        = [System.Environment]::MachineName
        OSCaption           = if ($os) { $os.Caption } else { "Windows" }
        OSVersion           = if ($os) { $os.Version } else { "Unknown" }
        BuildNumber         = if ($os) { $os.BuildNumber } else { 0 }
        CPUName             = if ($cpu) { $cpu.Name.Trim() } else { "Unknown CPU" }
        CPUCores            = if ($cpu) { $cpu.NumberOfCores } else { 0 }
        CPULogical          = if ($cpu) { $cpu.NumberOfLogicalProcessors } else { 0 }
        TotalRamGB          = $totalRam
        FreeRamGB           = $freeRam
        Uptime              = $uptime
        FirmwareType        = $firmwareType
        SecureBootEnabled   = $secureBootEnabled
        IsRebootPending     = $isRebootPending
        PendingCbsReboot    = $cbsReboot
        PendingWuReboot     = $wuReboot
        PendingFileRename   = $pendingFileRename
    }
}

function Test-WinPilotComponentStore {
    <#
    .SYNOPSIS
        Executes a non-destructive, read-only check of the Windows Component Store (DISM /CheckHealth).
    .DESCRIPTION
        Requires administrator elevation. If not elevated, reports status cleanly without error.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $isAdmin = Test-WinPilotAdmin
    if (-not $isAdmin) {
        Write-WinPilotLog -Level "WARN" -Component "Diagnostics" -Message "DISM CheckHealth skipped: elevation required"
        return [PSCustomObject]@{
            IsHealthy      = $null
            IsRepairable   = $null
            Status         = "ElevationRequired"
            SummaryMessage = "Administrator rights are required to query DISM component store."
            RawOutput      = ""
        }
    }

    Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "Running DISM /CheckHealth read-only audit"

    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "dism.exe"
        $pinfo.Arguments = "/Online /Cleanup-Image /CheckHealth"
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($pinfo)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        [void]$process.WaitForExit(30000)

        $output = "$stdout`n$stderr"
        $isHealthy = $null
        $isRepairable = $false
        $status = "Unknown"
        $msg = "DISM output could not be parsed."

        if ($output -match "No component store corruption detected") {
            $isHealthy = $true
            $status = "Healthy"
            $msg = "Component store is completely healthy. No corruption detected."
        }
        elseif ($output -match "The component store is repairable") {
            $isHealthy = $false
            $isRepairable = $true
            $status = "Repairable"
            $msg = "Component store corruption detected, but it is repairable via DISM RestoreHealth."
        }
        elseif ($output -match "The component store is non-repairable") {
            $isHealthy = $false
            $isRepairable = $false
            $status = "NonRepairable"
            $msg = "Component store corruption is marked non-repairable."
        }

        Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "DISM CheckHealth completed: $status"

        return [PSCustomObject]@{
            IsHealthy      = $isHealthy
            IsRepairable   = $isRepairable
            Status         = $status
            SummaryMessage = $msg
            RawOutput      = $output
        }
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "Diagnostics" -Message "DISM execution failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            IsHealthy      = $null
            IsRepairable   = $null
            Status         = "Error"
            SummaryMessage = "DISM execution exception: $($_.Exception.Message)"
            RawOutput      = ""
        }
    }
}

function Show-WinPilotSystemHealthReport {
    <#
    .SYNOPSIS
        Displays a structured visual TUI report of hardware, boot state, and component store.
    #>
    [CmdletBinding()]
    param()

    $health = Get-WinPilotSystemHealth
    $dism = Test-WinPilotComponentStore

    $reset = Get-WinPilotAnsiColor -ColorName "Reset"
    $cyan = Get-WinPilotAnsiColor -ColorName "BrightCyan"
    $green = Get-WinPilotAnsiColor -ColorName "BrightGreen"
    $yellow = Get-WinPilotAnsiColor -ColorName "BrightYellow"
    $red = Get-WinPilotAnsiColor -ColorName "BrightRed"
    $white = Get-WinPilotAnsiColor -ColorName "BrightWhite"
    $gray = Get-WinPilotAnsiColor -ColorName "Gray"

    $rebootBadge = if ($health.IsRebootPending) {
        "$yellow[PENDING REBOOT]$reset"
    } else {
        "$green[No Pending Reboot]$reset"
    }

    $sbBadge = if ($health.SecureBootEnabled) {
        "$green[Enabled]$reset"
    } else {
        "$yellow[Disabled / Legacy]$reset"
    }

    $dismBadge = switch ($dism.Status) {
        "Healthy"           { "$green[HEALTHY - No Corruption]$reset" }
        "Repairable"        { "$yellow[CORRUPTION DETECTED - Repairable]$reset" }
        "NonRepairable"     { "$red[CORRUPTION DETECTED - Non-repairable]$reset" }
        "ElevationRequired" { "$yellow[Elevation Required]$reset" }
        Default             { "$gray[$($dism.Status)]$reset" }
    }

    $lines = @(
        " ",
        "  Operating System  : $white$($health.OSCaption)$reset (Build $($health.BuildNumber))",
        "  Processor (CPU)   : $cyan$($health.CPUName)$reset ($($health.CPUCores) Cores / $($health.CPULogical) Threads)",
        "  System Memory     : $white$($health.FreeRamGB) GB free$reset / $($health.TotalRamGB) GB total",
        "  System Uptime     : $white$($health.Uptime)$reset",
        "  Firmware & Boot   : $white$($health.FirmwareType)$reset | Secure Boot: $sbBadge",
        "  Reboot State      : $rebootBadge",
        "  Component Store   : $dismBadge",
        "  DISM Diagnostic   : $gray$($dism.SummaryMessage)$reset",
        " "
    )

    Format-WinPilotBox -Title "SYSTEM SPECIFICATIONS & COMPONENT HEALTH" -Lines $lines -Width 76
}
