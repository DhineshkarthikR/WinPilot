<#
.SYNOPSIS
    WinPilot Official Office Deployment Execution Runner.

.DESCRIPTION
    Orchestrates the execution of official Microsoft Office Deployment Tool (setup.exe)
    for /download (offline cache) and /configure (live deployment) modes. Enforces
    mandatory confirmation guardrails, monitors progress, captures exit codes, and audits events.
#>

function Invoke-WinPilotOfficeDeploy {
    <#
    .SYNOPSIS
        Executes setup.exe with specified configuration XML and mode.
    .PARAMETER Mode
        Execution mode: 'Install' (/configure) or 'Download' (/download).
    .PARAMETER ConfigurationPath
        Path to the ODT configuration.xml file.
    .PARAMETER SetupPath
        Path to verified official setup.exe. If omitted, downloads/verifies automatically.
    .OUTPUTS
        [PSCustomObject] Execution result with ExitCode, Success, Mode, and StatusMessage.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Install", "Download")]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [string]$ConfigurationPath,

        [Parameter(Mandatory = $false)]
        [string]$SetupPath
    )

    if (-not (Test-Path -Path $ConfigurationPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]"Configuration XML file not found: $ConfigurationPath"
    }

    # Acquire and verify setup.exe if not provided
    if ([string]::IsNullOrEmpty($SetupPath) -or -not (Test-Path -Path $SetupPath)) {
        Write-WinPilotLog -Level "INFO" -Component "DeployRunner" -Message "Acquiring verified setup.exe from OdtEngine"
        $SetupPath = Get-WinPilotOdt
    }

    # Strict Authenticode verification on setup.exe before execution
    $isAuthentic = Test-WinPilotAuthenticode -Path $SetupPath -ExpectedSubject "Microsoft Corporation"
    if (-not $isAuthentic) {
        Write-WinPilotLog -Level "ERROR" -Component "DeployRunner" -Message "SECURITY ALERT: setup.exe Authenticode check failed. Aborting execution."
        throw "Security Error: setup.exe failed Authenticode verification. Execution halted."
    }

    # Mandatory Confirmation Guardrail for System-Altering Installations
    if ($Mode -eq "Install") {
        $confirmMsg = "Install Microsoft Office using configuration: $(Split-Path $ConfigurationPath -Leaf)"
        $isConfirmed = Confirm-WinPilotAction -ActionName $confirmMsg -RiskLevel "Moderate"
        if (-not $isConfirmed) {
            Write-WinPilotLog -Level "AUDIT" -Component "DeployRunner" -Message "User aborted Office installation at confirmation prompt."
            return [PSCustomObject]@{
                Success       = $false
                ExitCode      = -1
                Mode          = $Mode
                StatusMessage = "Operation cancelled by administrator."
            }
        }
    }

    $setupArg = if ($Mode -eq "Download") {
        "/download `"$ConfigurationPath`""
    } else {
        "/configure `"$ConfigurationPath`""
    }

    Write-WinPilotLog -Level "INFO" -Component "DeployRunner" -Message "Starting setup.exe $setupArg"
    Show-WinPilotBanner -Message "Executing Office Deployment Tool ($Mode mode)..." -Type "Info"

    $workDir = Split-Path -Path $ConfigurationPath -Parent
    $procResult = $null
    $exitCode = -1

    try {
        $procResult = Invoke-WinPilotProcess -FilePath $SetupPath -ArgumentList $setupArg -WorkingDirectory $workDir
        $exitCode = $procResult.ExitCode
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "DeployRunner" -Message "Exception launching setup.exe: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            Mode          = $Mode
            StatusMessage = "Execution failed with exception: $($_.Exception.Message)"
        }
    }

    $statusMessage = switch ($exitCode) {
        0     { "Office deployment completed successfully." }
        17002 { "Another installation is currently in progress, or setup was cancelled." }
        17004 { "Office installation was cancelled by user or interrupted." }
        30182 { "A network or connectivity error occurred while streaming Office files." }
        30088 { "Installation encountered an update conflict or disk space constraint." }
        Default { "Office setup completed with exit code: $exitCode." }
    }

    $isSuccess = ($exitCode -eq 0)
    $logLevel = if ($isSuccess) { "INFO" } else { "WARN" }
    Write-WinPilotLog -Level $logLevel -Component "DeployRunner" -Message "setup.exe finished ($Mode) - ExitCode: $exitCode ($statusMessage)"

    if ($isSuccess) {
        Show-WinPilotBanner -Message $statusMessage -Type "Success"
    } else {
        Show-WinPilotBanner -Message $statusMessage -Type "Warning"
    }

    return [PSCustomObject]@{
        Success       = $isSuccess
        ExitCode      = $exitCode
        Mode          = $Mode
        StatusMessage = $statusMessage
    }
}
