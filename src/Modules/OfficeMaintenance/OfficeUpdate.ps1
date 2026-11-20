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
        Write-WinPilotLog -Level "ERROR" -Component "OfficeUpdate" -Message "Office update execution exception: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            StatusMessage = "Execution exception: $($_.Exception.Message)"
        }
    }
    finally {
        if ($process) { $process.Dispose() }
    }

    $isSuccess = ($exitCode -eq 0)
    $msg = if ($isSuccess) { "Office update check completed successfully." } else { "Office update completed with exit code: $exitCode." }
    Write-WinPilotLog -Level $(if ($isSuccess) { "INFO" } else { "WARN" }) -Component "OfficeUpdate" -Message $msg

    if ($isSuccess) {
        Show-WinPilotBanner -Message $msg -Type "Success"
    } else {
        Show-WinPilotBanner -Message $msg -Type "Warning"
    }

    return [PSCustomObject]@{
        Success       = $isSuccess
        ExitCode      = $exitCode
        StatusMessage = $msg
    }
}
