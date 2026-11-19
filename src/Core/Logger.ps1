<#
.SYNOPSIS
    WinPilot Structured Audit and Diagnostics Logging Module.

.DESCRIPTION
    Provides timestamped, level-filtered logging to local files and console output.
    Maintains an audit trail of all operations and diagnostics.
#>

$script:WinPilotLogDirectory = $null
$script:WinPilotCurrentLogFile = $null

function Initialize-WinPilotLogger {
    <#
    .SYNOPSIS
        Initializes the log directory and creates the daily log file.
    .PARAMETER BasePath
        Optional custom path for log files. Defaults to ProgramData or Temp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BasePath
    )

    if (-not [string]::IsNullOrEmpty($BasePath)) {
        $targetDir = $BasePath
    }
    else {
        $programData = [System.Environment]::GetEnvironmentVariable("ProgramData")
        if (-not [string]::IsNullOrEmpty($programData)) {
            $targetDir = [System.IO.Path]::Combine($programData, "WinPilot", "Logs")
        }
        else {
            $targetDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "Logs")
        }
    }

    try {
        if (-not (Test-Path -Path $targetDir)) {
            [void](New-Item -ItemType Directory -Path $targetDir -Force -ErrorAction Stop)
        }
    }
    catch {
        # Fall back to user temp directory if ProgramData requires elevation
        $targetDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "Logs")
        if (-not (Test-Path -Path $targetDir)) {
            [void](New-Item -ItemType Directory -Path $targetDir -Force)
        }
    }

    $dateStamp = Get-Date -Format "yyyyMMdd"
    $script:WinPilotLogDirectory = $targetDir
    $script:WinPilotCurrentLogFile = [System.IO.Path]::Combine($targetDir, "winpilot-$dateStamp.log")

    Write-WinPilotLog -Level "INFO" -Component "Logger" -Message "Logging initialized at $script:WinPilotCurrentLogFile"
}

function Get-WinPilotLogPath {
    <#
    .SYNOPSIS
        Returns the path of the current active log file.
    #>
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrEmpty($script:WinPilotCurrentLogFile)) {
        Initialize-WinPilotLogger
    }
    return $script:WinPilotCurrentLogFile
}

function Write-WinPilotLog {
    <#
    .SYNOPSIS
        Appends a structured log entry to the log file and optionally displays it.
    .PARAMETER Message
        The message content to record.
    .PARAMETER Level
        Severity level: INFO, WARN, ERROR, DEBUG, AUDIT.
    .PARAMETER Component
        Originating module or subsystem name.
    .PARAMETER MirrorToConsole
        Whether to print the message to standard console output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [string]$Component = "Core",

        [Parameter(Mandatory = $false)]
        [switch]$MirrorToConsole
    )

    if ([string]::IsNullOrEmpty($script:WinPilotCurrentLogFile)) {
        Initialize-WinPilotLogger
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $logLine = "[$timestamp] [$Level] [$Component] $Message"

    try {
        [System.IO.File]::AppendAllText($script:WinPilotCurrentLogFile, "$logLine`r`n", [System.Text.Encoding]::UTF8)
    }
    catch {
        # Silently continue if file write is locked
    }

    if ($MirrorToConsole) {
        switch ($Level) {
            "ERROR" { Write-Host $logLine -ForegroundColor Red }
            "WARN"  { Write-Host $logLine -ForegroundColor Yellow }
            "AUDIT" { Write-Host $logLine -ForegroundColor Cyan }
            "DEBUG" { Write-Host $logLine -ForegroundColor DarkGray }
            Default { Write-Host $logLine -ForegroundColor White }
        }
    }
}
