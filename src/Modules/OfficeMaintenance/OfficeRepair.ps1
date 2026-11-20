<#
.SYNOPSIS
    WinPilot Microsoft Office Repair Subsystem (Quick Repair & Online Repair).

.DESCRIPTION
    Provides automated invocation of the official Microsoft Click-to-Run repair engine:
    - Quick Repair: Launches the supported Windows Click-to-Run repair interface and guides
      the user step-by-step through local file verification without internet dependency.
    - Online Repair: Invokes Microsoft's documented OfficeClickToRun.exe scenario=Repair
      command with architecture detection, forceappshutdown warnings, and cloud reinstall.
    Enforces Authenticode verification on OfficeClickToRun.exe (as registered in Windows ARP)
    and explicit confirmation guards.
#>

function Get-WinPilotC2RClient {
    <#
    .SYNOPSIS
        Locates and validates the Authenticode signature of the official Click-to-Run repair engine.
    .DESCRIPTION
        Discovers the native Office Click-to-Run execution engine (OfficeClickToRun.exe)
        as registered by Windows Add/Remove Programs (ARP) for Repair. Enforces strict
        Authenticode verification, certificate chain trust, Code Signing EKU, and genuine
        binary identity.
    .OUTPUTS
        [string] Path to verified OfficeClickToRun.exe.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $candidatePaths = New-Object System.Collections.Generic.List[string]

    # 1. Discover registered ModifyPath from Windows Add/Remove Programs (ARP)
    $arpKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($arpKey in $arpKeys) {
        $items = Get-ItemProperty -Path $arpKey -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*Microsoft 365*" -or $_.DisplayName -like "*Microsoft Office*"
        }
        foreach ($item in $items) {
            if ($item.ModifyPath) {
                $rawPath = $item.ModifyPath.Trim()
                if ($rawPath.StartsWith('"')) {
                    $endQuote = $rawPath.IndexOf('"', 1)
                    if ($endQuote -gt 1) {
                        $parsedExe = $rawPath.Substring(1, $endQuote - 1)
                        if ($parsedExe -notin $candidatePaths) { $candidatePaths.Add($parsedExe) }
                    }
                }
                else {
                    $spaceIdx = $rawPath.IndexOf(' ')
                    $parsedExe = if ($spaceIdx -gt 0) { $rawPath.Substring(0, $spaceIdx) } else { $rawPath }
                    if ($parsedExe -notin $candidatePaths) { $candidatePaths.Add($parsedExe) }
                }
            }
        }
    }

    # 2. Check Click-to-Run Configuration ClientFolder
    $clientFolder = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue).ClientFolder
    if (-not [string]::IsNullOrEmpty($clientFolder)) {
        $p1 = Join-Path $clientFolder "OfficeClickToRun.exe"
        if ($p1 -notin $candidatePaths) { $candidatePaths.Add($p1) }
    }

    # 3. Standard ClickToRun shared directories
    $stdPaths = @(
        "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    )
    foreach ($sp in $stdPaths) {
        if ($sp -notin $candidatePaths) { $candidatePaths.Add($sp) }
    }

    foreach ($path in $candidatePaths) {
        if (Test-Path -Path $path -PathType Leaf) {
            $isAuthentic = Test-WinPilotAuthenticode -Path $path -ExpectedSubject "Microsoft Corporation"
            if ($isAuthentic) {
                # Strict binary identity check: Ensure target is genuine OfficeClickToRun.exe
                $versionInfo = (Get-Item -Path $path).VersionInfo
                $isGenuineC2R = ($versionInfo.OriginalFilename -eq "OfficeClickToRun.exe") -or
                                ($versionInfo.FileDescription -like "*Click-to-Run*")

                if ($isGenuineC2R) {
                    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Verified OfficeClickToRun.exe found at: $path"
                    return $path
                }
                else {
                    Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Binary at $path is signed by Microsoft but is not OfficeClickToRun.exe. Rejected."
                }
            }
            else {
                Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Candidate repair engine failed signature check: $path"
            }
        }
    }

    Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "OfficeClickToRun.exe repair engine not found on system"
    return $null
}

function Invoke-WinPilotOfficeQuickRepair {
    <#
    .SYNOPSIS
        Guides the user through Quick Repair using the supported Windows Installed Apps interface.
    .DESCRIPTION
        Launches the supported Windows Installed Apps interface (ms-settings:installed-apps)
        and guides the user step-by-step through selecting Modify -> Quick Repair.
        Reports that the interface was launched, not that repair completed.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $inventory = Get-WinPilotOfficeInstallationInventory

    if (-not $inventory.IsInstalled) {
        Show-WinPilotBanner -Message "Click-to-Run Office installation not found on this system." -Type "Warning"
        return [PSCustomObject]@{
            Success       = $false
            Launched      = $false
            Completed     = "Failed"
            ExitCode      = -1
            Scenario      = "QuickRepair"
            StatusMessage = "Click-to-Run Office installation not found on this system."
        }
    }

    $isConfirmed = Confirm-WinPilotAction -ActionName "Open Windows Installed Apps Interface for Quick Repair" -RiskLevel "Low"
    if (-not $isConfirmed) {
        return [PSCustomObject]@{
            Success       = $false
            Launched      = $false
            Completed     = "Cancelled"
            ExitCode      = -1
            Scenario      = "QuickRepair"
            StatusMessage = "Operation cancelled by user."
        }
    }

    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "  SUPPORTED WINDOWS APPLICATION REPAIR INTERFACE (QUICK REPAIR)" -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "  Microsoft supports Quick Repair via the Windows Installed Apps interface." -ForegroundColor White
    Write-Host ""
    Write-Host "  STEP-BY-STEP INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "  1. Windows Settings (Installed Apps) will now open." -ForegroundColor White
    Write-Host "  2. Locate your Office product (e.g. 'Microsoft 365' or 'Office 2021')." -ForegroundColor White
    Write-Host "  3. Click the three dots (...) or select the app and click 'Modify'." -ForegroundColor White
    Write-Host "  4. In the dialog that appears, choose 'Quick Repair' and click 'Repair'." -ForegroundColor White
    Write-Host ""
    Write-Host "  [NOTICE] WinPilot reports that the Settings interface was launched." -ForegroundColor DarkGray
    Write-Host "  Repair execution proceeds interactively in the Windows user session." -ForegroundColor DarkGray
    Write-Host ""

    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Launching Windows Installed Apps interface (ms-settings:installed-apps)"
    Show-WinPilotBanner -Message "Launching Windows Installed Apps settings interface..." -Type "Info"

    $launched = $false
    try {
        Start-Process "ms-settings:installed-apps"
        $launched = $true
    }
    catch {
        try {
            Start-Process "ms-settings:appsfeatures"
            $launched = $true
        }
        catch {
            Write-WinPilotLog -Level "ERROR" -Component "OfficeRepair" -Message "Failed to launch Settings interface: $($_.Exception.Message)"
            return [PSCustomObject]@{
                Success       = $false
                Launched      = $false
                Completed     = "Failed"
                ExitCode      = -1
                Scenario      = "QuickRepair"
                StatusMessage = "Failed to launch Windows Settings interface: $($_.Exception.Message)"
            }
        }
    }

    $msg = "Windows Installed Apps interface launched successfully. Follow guided steps: Modify -> Quick Repair."
    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message $msg
    Show-WinPilotBanner -Message $msg -Type "Success"

    return [PSCustomObject]@{
        Success       = $launched
        Launched      = $launched
        Completed     = "External"
        ExitCode      = 0
        Scenario      = "QuickRepair"
        StatusMessage = $msg
    }
}

function Invoke-WinPilotOfficeOnlineRepair {
    <#
    .SYNOPSIS
        Triggers an Office Online Repair using Microsoft's documented OfficeClickToRun.exe scenario=Repair command.
    .DESCRIPTION
        Executes cloud-streamed reinstall using the native Click-to-Run engine with architecture detection.
        Displays mandatory warnings that forceappshutdown=True can cause unsaved work to be lost.
        Clearly distinguishes launching the repair operation from confirming that it completed.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $c2rExe = Get-WinPilotC2RClient
    $inventory = Get-WinPilotOfficeInstallationInventory

    if (-not $c2rExe) {
        Show-WinPilotBanner -Message "OfficeClickToRun.exe repair engine not found on this system." -Type "Warning"
        return [PSCustomObject]@{
            Success       = $false
            Launched      = $false
            Completed     = "Failed"
            ExitCode      = -1
            Scenario      = "OnlineRepair"
            StatusMessage = "OfficeClickToRun.exe not found or failed signature verification."
        }
    }

    # Record Pre-Operation State
    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Pre-OnlineRepair state: Products=$($inventory.ProductReleaseIds -join ', '), Version=$($inventory.Version), Platform=$($inventory.Platform), Channel=$($inventory.UpdateChannel)"

    # Architecture Detection
    $platform = if ($inventory.Platform -match "x86|32") { "x86" } else { "x64" }
    $culture = if ($inventory.Languages -and $inventory.Languages.Count -gt 0) { $inventory.Languages[0] } else { "en-us" }

    # Mandatory Application Shutdown & Data Loss Warning
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host "  CRITICAL WARNING: APPLICATION SHUTDOWN & DATA LOSS RISK" -ForegroundColor Red
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host "  - Online Repair with forceappshutdown=True will forcefully close" -ForegroundColor Yellow
    Write-Host "    all running Office programs (Word, Excel, PowerPoint, Outlook, OneNote)." -ForegroundColor Yellow
    Write-Host "  - ANY UNSAVED WORK IN OPEN OFFICE DOCUMENTS WILL BE LOST!" -ForegroundColor Red
    Write-Host "  - An active internet connection is mandatory for cloud reinstall." -ForegroundColor White
    Write-Host "  - Existing user documents and mailboxes will not be deleted." -ForegroundColor White
    Write-Host "  - Target Architecture: $platform | Target Culture: $culture" -ForegroundColor Gray
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host ""

    $isConfirmed = Confirm-WinPilotAction -ActionName "Microsoft Office Online Repair ($platform, Cloud Stream Reinstall)" -RiskLevel "High" -RequiresTypedConfirmation
    if (-not $isConfirmed) {
        return [PSCustomObject]@{
            Success       = $false
            Launched      = $false
            Completed     = "Cancelled"
            ExitCode      = -1
            Scenario      = "OnlineRepair"
            StatusMessage = "Operation cancelled by user."
        }
    }

    $arg = "scenario=Repair platform=$platform culture=$culture RepairType=FullRepair DisplayLevel=True forceappshutdown=True"
    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Executing Office Online Repair via OfficeClickToRun.exe with args: $arg"
    Show-WinPilotBanner -Message "Launching Office Online Repair (streaming from Microsoft CDN)..." -Type "Info"

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $c2rExe
    $pinfo.Arguments = $arg
    $pinfo.UseShellExecute = $false

    $process = $null
    $exitCode = -1

    try {
        $process = [System.Diagnostics.Process]::Start($pinfo)
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 500
        }
        $exitCode = $process.ExitCode
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "OfficeRepair" -Message "Online Repair execution error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success       = $false
            Launched      = $false
            Completed     = "Failed"
            ExitCode      = -1
            Scenario      = "OnlineRepair"
            StatusMessage = "Execution exception: $($_.Exception.Message)"
        }
    }
    finally {
        if ($process) { $process.Dispose() }
    }

    $isSuccess = ($exitCode -eq 0)
    $msg = if ($isSuccess) {
        "Office Online Repair initiated successfully. Click-to-Run service is streaming packages in the background."
    } else {
        "Office Online Repair process exited with code: $exitCode."
    }
    Write-WinPilotLog -Level $(if ($isSuccess) { "INFO" } else { "WARN" }) -Component "OfficeRepair" -Message $msg

    if ($isSuccess) {
        Show-WinPilotBanner -Message $msg -Type "Success"
        Write-Host "  [STATUS NOTICE] Process launch completed. Package streaming proceeds via Click-to-Run service." -ForegroundColor Cyan
    } else {
        Show-WinPilotBanner -Message $msg -Type "Warning"
        Write-Host "  Recovery Guidance: If Office fails to launch, restart and re-run Online Repair or deploy using WinPilot Menu [2]." -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        Success       = $isSuccess
        Launched      = $true
        Completed     = if ($isSuccess) { "Initiated" } else { "Error" }
        ExitCode      = $exitCode
        Scenario      = "OnlineRepair"
        StatusMessage = $msg
    }
}
