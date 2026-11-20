<#
.SYNOPSIS
    WinPilot Microsoft Office Repair Subsystem (Quick Repair & Online Repair).

.DESCRIPTION
    Provides automated invocation of official Microsoft Click-to-Run repair scenarios:
    - Quick Repair: Scans and repairs corrupt Office files locally without internet access.
    - Online Repair: Reinstalls and streams complete Office packages from Microsoft CDN.
    Enforces Authenticode verification on OfficeC2RClient.exe and explicit confirmation guards.
#>

function Get-WinPilotC2RClient {
    <#
    .SYNOPSIS
        Locates and validates the Authenticode signature of the official OfficeC2RClient.exe.
    .OUTPUTS
        [string] Path to verified OfficeC2RClient.exe.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $clientFolder = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue).ClientFolder
    $candidatePaths = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrEmpty($clientFolder)) {
        $candidatePaths.Add((Join-Path $clientFolder "OfficeC2RClient.exe"))
    }

    $candidatePaths.Add("$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe")
    $candidatePaths.Add("${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe")

    foreach ($path in $candidatePaths) {
        if (Test-Path -Path $path -PathType Leaf) {
            $isAuthentic = Test-WinPilotAuthenticode -Path $path -ExpectedSubject "Microsoft Corporation"
            if ($isAuthentic) {
                # Strict binary identity check: Prevent spoofing by an unrelated Microsoft-signed binary
                $versionInfo = (Get-Item -Path $path).VersionInfo
                $isGenuineC2R = ($versionInfo.OriginalFilename -eq "OfficeC2RClient.exe") -or 
                                ($versionInfo.FileDescription -like "*Click-to-Run*")

                if ($isGenuineC2R) {
                    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Verified OfficeC2RClient.exe found at: $path"
                    return $path
                }
                else {
                    Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Binary at $path is signed by Microsoft but is not OfficeC2RClient. Rejected."
                }
            }
            else {
                Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "Found OfficeC2RClient.exe failed signature check: $path"
            }
        }
    }

    Write-WinPilotLog -Level "WARN" -Component "OfficeRepair" -Message "OfficeC2RClient.exe not found on system"
    return $null
}

function Invoke-WinPilotOfficeQuickRepair {
    <#
    .SYNOPSIS
        Triggers an official Click-to-Run Quick Repair of local Office installations.
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
            StatusMessage = "OfficeC2RClient.exe not found or failed signature verification."
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

    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Initiating Office Quick Repair"
    Show-WinPilotBanner -Message "Starting Office Quick Repair..." -Type "Info"

    $arg = "/repair DisplayLevel=True Scenario=QuickRepair"
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
        Triggers an official Click-to-Run Online Repair (stream reinstall from Microsoft CDN).
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
            StatusMessage = "OfficeC2RClient.exe not found or failed signature verification."
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

    Write-WinPilotLog -Level "INFO" -Component "OfficeRepair" -Message "Initiating Office Online Repair"
    Show-WinPilotBanner -Message "Starting Office Online Repair (streaming from Microsoft CDN)..." -Type "Info"

    $arg = "/repair DisplayLevel=True Scenario=Repair"
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
