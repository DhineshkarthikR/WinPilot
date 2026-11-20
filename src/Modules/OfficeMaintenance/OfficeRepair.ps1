<#
.SYNOPSIS
    WinPilot Microsoft Office Repair Subsystem (Quick Repair & Online Repair).

.DESCRIPTION
    Provides automated invocation of Click-to-Run repair engine scenarios:
    - Quick Repair: Scans and repairs corrupt Office files locally without internet access.
    - Online Repair: Reinstalls and streams complete Office packages from Microsoft CDN.
    Enforces Authenticode verification on the Click-to-Run engine (OfficeClickToRun.exe
    as registered by Windows Add/Remove Programs) and explicit confirmation guards.

    Technical Notice:
    Command-line repair invocations (scenario=Repair, RepairType=QuickRepair/FullRepair)
    are internal Click-to-Run engine parameters utilized by Windows Add/Remove Programs
    (ARP) Modify integration. They are not publicly documented Microsoft Learn API
    command-line switches. Microsoft officially recommends performing repairs via
    Windows Settings > Installed Apps > Modify.
#>

function Get-WinPilotC2RClient {
    <#
    .SYNOPSIS
        Locates and validates the Authenticode signature of the official Click-to-Run engine.
    .DESCRIPTION
        Discovers the native Office Click-to-Run execution engine (OfficeClickToRun.exe)
        as registered by Windows Add/Remove Programs (ARP) for Repair, or the client launcher
        (OfficeC2RClient.exe). Enforces strict Authenticode verification, certificate chain
        trust, Code Signing EKU, and genuine binary identity.
    .OUTPUTS
        [string] Path to verified Click-to-Run executable.
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
                # Extract quoted or unquoted executable path
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
        $p2 = Join-Path $clientFolder "OfficeC2RClient.exe"
        if ($p2 -notin $candidatePaths) { $candidatePaths.Add($p2) }
    }

    # 3. Standard ClickToRun shared directories
    $stdPaths = @(
        "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
        "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    )
    foreach ($sp in $stdPaths) {
        if ($sp -notin $candidatePaths) { $candidatePaths.Add($sp) }
    }

    foreach ($path in $candidatePaths) {
        if (Test-Path -Path $path -PathType Leaf) {
            $isAuthentic = Test-WinPilotAuthenticode -Path $path -ExpectedSubject "Microsoft Corporation"
            if ($isAuthentic) {
                # Strict binary identity check: Prevent spoofing by an unrelated Microsoft-signed binary
                $versionInfo = (Get-Item -Path $path).VersionInfo
                $isGenuineC2R = ($versionInfo.OriginalFilename -in @("OfficeClickToRun.exe", "OfficeC2RClient.exe")) -or
                                ($versionInfo.FileDescription -like "*Click-to-Run*")

                if ($isGenuineC2R) {
                    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Verified Click-to-Run engine found at: $path"
                    return $path
                }
                else {
                    Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Binary at $path is signed by Microsoft but is not Office Click-to-Run engine. Rejected."
                }
            }
            else {
                Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Found candidate engine failed signature check: $path"
            }
        }
    }

    Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Click-to-Run repair engine not found on system"
    return $null
}

function Invoke-WinPilotOfficeQuickRepair {
    <#
    .SYNOPSIS
        Triggers a Click-to-Run Quick Repair of local Office installations.
    .DESCRIPTION
        Executes local file and registry verification using the native Click-to-Run engine.
        Note: Uses internal Click-to-Run engine parameters derived from Windows Add/Remove Programs.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $c2rExe = Get-WinPilotC2RClient
    if (-not $c2rExe) {
        Show-WinPilotBanner -Message "Click-to-Run Office installation not found on this system." -Type "Warning"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            Scenario      = "QuickRepair"
            StatusMessage = "Click-to-Run engine not found or failed signature verification."
        }
    }

    $isConfirmed = Confirm-WinPilotAction -ActionName "Microsoft Office Quick Repair (Local Scan & Fix)" -RiskLevel "Low"
    if (-not $isConfirmed) {
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            Scenario      = "QuickRepair"
            StatusMessage = "Operation cancelled by user."
        }
    }

    # Query installed platform and culture from Click-to-Run configuration
    $c2rProps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
    $platform = if ($c2rProps.Platform) { $c2rProps.Platform } else { if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" } }
    $culture = if ($c2rProps.ClientCulture) { $c2rProps.ClientCulture } else { "en-us" }

    $isClickToRunExe = (Split-Path $c2rExe -Leaf).Equals("OfficeClickToRun.exe", [System.StringComparison]::OrdinalIgnoreCase)
    $arg = if ($isClickToRunExe) {
        "scenario=Repair platform=$platform culture=$culture RepairType=QuickRepair DisplayLevel=True"
    } else {
        "/repair DisplayLevel=True Scenario=QuickRepair"
    }

    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Initiating Office Quick Repair via $(Split-Path $c2rExe -Leaf) with args: $arg"
    Show-WinPilotBanner -Message "Starting Office Quick Repair..." -Type "Info"

    Write-Host "  [TECHNICAL NOTICE - CLICK-TO-RUN ENGINE REPAIR]" -ForegroundColor Cyan
    Write-Host "  - Executing Click-to-Run engine repair parameters ($arg)." -ForegroundColor Gray
    Write-Host "  - These parameters are internal engine switches used by Windows Add/Remove Programs (ARP)." -ForegroundColor Gray
    Write-Host "  - They are not a separate public Microsoft Learn CLI specification." -ForegroundColor Gray
    Write-Host ""

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
        Write-WinPilotLog -Level "ERROR" -Component "OfficeRepair" -Message "Quick Repair execution error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            Scenario      = "QuickRepair"
            StatusMessage = "Execution exception: $($_.Exception.Message)"
        }
    }
    finally {
        if ($process) { $process.Dispose() }
    }

    $isSuccess = ($exitCode -eq 0)
    $msg = if ($isSuccess) { "Office Quick Repair completed successfully." } else { "Quick Repair completed with exit code: $exitCode." }
    Write-WinPilotLog -Level $(if ($isSuccess) { "INFO" } else { "WARN" }) -Component "OfficeRepair" -Message $msg

    if ($isSuccess) {
        Show-WinPilotBanner -Message $msg -Type "Success"
    } else {
        Show-WinPilotBanner -Message $msg -Type "Warning"
    }

    return [PSCustomObject]@{
        Success       = $isSuccess
        ExitCode      = $exitCode
        Scenario      = "QuickRepair"
        StatusMessage = $msg
    }
}

function Invoke-WinPilotOfficeOnlineRepair {
    <#
    .SYNOPSIS
        Triggers an Office Online Repair (stream reinstall from Microsoft CDN).
    .DESCRIPTION
        Executes a complete cloud-streamed reinstall using the native Click-to-Run engine.
        Note: Uses internal Click-to-Run engine parameters derived from Windows Add/Remove Programs.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $c2rExe = Get-WinPilotC2RClient
    if (-not $c2rExe) {
        Show-WinPilotBanner -Message "Click-to-Run Office installation not found on this system." -Type "Warning"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            Scenario      = "OnlineRepair"
            StatusMessage = "Click-to-Run engine not found or failed signature verification."
        }
    }

    # Record Pre-Operation State
    $subInfo = Get-WinPilotOfficeSubscriptionStatus
    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Pre-OnlineRepair state: Products=$($subInfo.ProductReleaseIds), Version=$($subInfo.Version), Channel=$($subInfo.UpdateChannel)"

    Write-Host ""
    Write-Host "  [IMPORTANT NOTE REGARDING ONLINE REPAIR]" -ForegroundColor Yellow
    Write-Host "  Online Repair completely reinstalls all Office binaries from the Microsoft CDN." -ForegroundColor White
    Write-Host "  - An active internet connection is mandatory." -ForegroundColor Gray
    Write-Host "  - Existing user documents, personal files, and mailboxes will NOT be deleted." -ForegroundColor Gray
    Write-Host "  - If interrupted by network loss, rerun Online Repair or run WinPilot Office Deployment." -ForegroundColor Gray
    Write-Host ""

    $isConfirmed = Confirm-WinPilotAction -ActionName "Microsoft Office Online Repair (Cloud Stream Reinstall)" -RiskLevel "High" -RequiresTypedConfirmation
    if (-not $isConfirmed) {
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            Scenario      = "OnlineRepair"
            StatusMessage = "Operation cancelled by user."
        }
    }

    # Query installed platform and culture from Click-to-Run configuration
    $c2rProps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
    $platform = if ($c2rProps.Platform) { $c2rProps.Platform } else { if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" } }
    $culture = if ($c2rProps.ClientCulture) { $c2rProps.ClientCulture } else { "en-us" }

    $isClickToRunExe = (Split-Path $c2rExe -Leaf).Equals("OfficeClickToRun.exe", [System.StringComparison]::OrdinalIgnoreCase)
    $arg = if ($isClickToRunExe) {
        "scenario=Repair platform=$platform culture=$culture RepairType=FullRepair DisplayLevel=True"
    } else {
        "/repair DisplayLevel=True Scenario=Repair"
    }

    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Initiating Office Online Repair via $(Split-Path $c2rExe -Leaf) with args: $arg"
    Show-WinPilotBanner -Message "Starting Office Online Repair (streaming from Microsoft CDN)..." -Type "Info"

    Write-Host "  [TECHNICAL NOTICE - CLICK-TO-RUN ENGINE REPAIR]" -ForegroundColor Cyan
    Write-Host "  - Executing Click-to-Run engine repair parameters ($arg)." -ForegroundColor Gray
    Write-Host "  - These parameters are internal engine switches used by Windows Add/Remove Programs (ARP)." -ForegroundColor Gray
    Write-Host "  - They are not a separate public Microsoft Learn CLI specification." -ForegroundColor Gray
    Write-Host ""

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
            ExitCode      = -1
            Scenario      = "OnlineRepair"
            StatusMessage = "Execution exception: $($_.Exception.Message)"
        }
    }
    finally {
        if ($process) { $process.Dispose() }
    }

    $isSuccess = ($exitCode -eq 0)
    $msg = if ($isSuccess) { "Office Online Repair completed successfully." } else { "Online Repair completed with exit code: $exitCode." }
    Write-WinPilotLog -Level $(if ($isSuccess) { "INFO" } else { "WARN" }) -Component "OfficeRepair" -Message $msg

    if ($isSuccess) {
        Show-WinPilotBanner -Message $msg -Type "Success"
    } else {
        Show-WinPilotBanner -Message $msg -Type "Warning"
        Write-Host "  Recovery Guidance: If Office applications fail to open, re-run Online Repair or deploy using WinPilot Menu [2]." -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        Success       = $isSuccess
        ExitCode      = $exitCode
        Scenario      = "OnlineRepair"
        StatusMessage = $msg
    }
}
