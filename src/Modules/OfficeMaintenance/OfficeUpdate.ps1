<#
.SYNOPSIS
    WinPilot Microsoft Office Click-to-Run Update Subsystem.

.DESCRIPTION
    Inspects Click-to-Run update configuration, checks for updates against
    configured Microsoft CDN channels, triggers background updates, and captures
    execution status.
#>

function Get-WinPilotOfficeUpdateConfig {
    <#
    .SYNOPSIS
        Retrieves the current Click-to-Run update configuration from registry.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $c2rReg = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    if (-not (Test-Path -Path $c2rReg)) {
        return [PSCustomObject]@{
            IsInstalled    = $false
            Version        = "None"
            UpdateChannel  = "None"
            UpdatesEnabled = $false
        }
    }

    $props = Get-ItemProperty -Path $c2rReg -ErrorAction SilentlyContinue
    $updatesEnabled = $true
    if ($props.UpdatesEnabled -eq "False" -or $props.UpdatesEnabled -eq 0) {
        $updatesEnabled = $false
    }

    return [PSCustomObject]@{
        IsInstalled    = $true
        Version        = if ($props.VersionToReport) { $props.VersionToReport } else { "Unknown" }
        UpdateChannel  = if ($props.UpdateChannel) { $props.UpdateChannel } else { "Unknown" }
        UpdatesEnabled = $updatesEnabled
    }
}

function Invoke-WinPilotOfficeUpdate {
    <#
    .SYNOPSIS
        Triggers an official Click-to-Run update check and deployment.
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
            StatusMessage = "OfficeC2RClient.exe not found or failed signature verification."
        }
    }

    $updateConfig = Get-WinPilotOfficeUpdateConfig
    Write-WinPilotLog -Level "INFO" -Component "OfficeUpdate" -Message "Current Office Version: $($updateConfig.Version), Channel: $($updateConfig.UpdateChannel), UpdatesEnabled: $($updateConfig.UpdatesEnabled)"

    $isConfirmed = Confirm-WinPilotAction -ActionName "Check & Apply Microsoft Office Updates" -RiskLevel "Low"
    if (-not $isConfirmed) {
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            StatusMessage = "Operation cancelled by user."
        }
    }

    Write-WinPilotLog -Level "INFO" -Component "OfficeUpdate" -Message "Triggering OfficeC2RClient update check"
    Show-WinPilotBanner -Message "Checking and applying Microsoft Office updates..." -Type "Info"

    $arg = "/update user displaylevel=true"
    $procResult = $null
    $exitCode = -1

    try {
        $procResult = Invoke-WinPilotProcess -FilePath $c2rExe -ArgumentList $arg
        $exitCode = $procResult.ExitCode
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "OfficeUpdate" -Message "Office update execution exception: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            StatusMessage = "Execution exception: $($_.Exception.Message)"
        }
    }

    $isSuccess = ($exitCode -eq 0)
    $msg = if ($isSuccess) {
        "Office update client triggered successfully. Update inspection and download will proceed in the background."
    } else {
        "Office update trigger completed with exit code: $exitCode."
    }
    Write-WinPilotLog -Level $(if ($isSuccess) { "INFO" } else { "WARN" }) -Component "OfficeUpdate" -Message $msg

    if ($isSuccess) {
        Show-WinPilotBanner -Message $msg -Type "Success"
        Write-Host "  [UPDATE STATUS EXPLANATION]" -ForegroundColor Cyan
        Write-Host "  - The Click-to-Run update engine runs asynchronously in the background via the ClickToRun service." -ForegroundColor Gray
        Write-Host "  - Launching the client succeeded; package download and installation take place out-of-process." -ForegroundColor Gray
        Write-Host "  - If applications need to close to apply updates, Office will display a native notification prompt." -ForegroundColor Gray
    } else {
        Show-WinPilotBanner -Message $msg -Type "Warning"
    }

    return [PSCustomObject]@{
        Success       = $isSuccess
        ExitCode      = $exitCode
        Triggered     = $isSuccess
        StatusMessage = $msg
    }
}
