<#
.SYNOPSIS
    WinPilot Root PowerShell Module Loader and Interactive Orchestrator.

.DESCRIPTION
    Loads core subsystem scripts, configures console settings, initializes
    audit logging, and provides the main interactive TUI navigation loop.
#>

$corePath = [System.IO.Path]::Combine($PSScriptRoot, "Core")
$securityPath = [System.IO.Path]::Combine($PSScriptRoot, "Security")

# Dot-source Core subsystem scripts in order
. (Join-Path $corePath "Host.ps1")
. (Join-Path $corePath "Logger.ps1")
. (Join-Path $corePath "AnsiUI.ps1")
. (Join-Path $corePath "Input.ps1")

# Dot-source Security subsystem scripts
. (Join-Path $securityPath "Integrity.ps1")
. (Join-Path $securityPath "SignatureVerifier.ps1")
. (Join-Path $securityPath "SecureBootstrapper.ps1")

# Configure console and logging upon module import
Initialize-WinPilotConsole
Initialize-WinPilotLogger

function Start-WinPilot {
    <#
    .SYNOPSIS
        Launches the interactive WinPilot Terminal User Interface.
    .DESCRIPTION
        Displays the main dashboard menu and routes user selections to
        diagnostics, deployment, maintenance, and repair subsystems.
    #>
    [CmdletBinding()]
    param()

    $running = $true

    while ($running) {
        Clear-WinPilotScreen
        Show-WinPilotHeader -Subtitle "Independent Windows & Office Management Toolkit"

        $menuLines = @(
            " ",
            "  [1] Diagnostics & Licensing Auditing    (Supported Microsoft APIs)",
            "  [2] Office Deployment Suite             (Official Microsoft ODT)",
            "  [3] Office Maintenance & Repair         (C2R Quick/Online, Updates)",
            "  [4] Windows System & Store Health       (SFC, DISM, Component Store)",
            "  [5] View Local Audit Log                (Session Transcripts)",
            " ",
            "  [0] Exit WinPilot",
            " "
        )

        Format-WinPilotBox -Title "MAIN MENU" -Lines $menuLines -Width 76
        Write-Host ""

        $choice = Read-WinPilotChoice -ValidKeys @('1', '2', '3', '4', '5', '0', 'Q') -Prompt "  Select an option [0-5]: "

        switch ($choice) {
            '1' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Diagnostics & Licensing"
                Show-WinPilotBanner -Message "Diagnostics subsystem reserved for Milestone 2." -Type "Info"
                Write-Host ""
                Write-Host "  Press any key to return to main menu..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '2' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Office Deployment Suite"
                Show-WinPilotBanner -Message "Office Deployment subsystem reserved for Milestone 3." -Type "Info"
                Write-Host ""
                Write-Host "  Press any key to return to main menu..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '3' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Office Maintenance & Repair"
                Show-WinPilotBanner -Message "Office Maintenance subsystem reserved for Milestone 4." -Type "Info"
                Write-Host ""
                Write-Host "  Press any key to return to main menu..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '4' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Windows System & Store Health"
                Show-WinPilotBanner -Message "System Repair subsystem reserved for Milestone 5." -Type "Info"
                Write-Host ""
                Write-Host "  Press any key to return to main menu..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '5' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Audit Log Viewer"
                $logPath = Get-WinPilotLogPath
                Write-Host "  Current Log File: $logPath" -ForegroundColor Cyan
                Write-Host ""
                if (Test-Path $logPath) {
                    Get-Content $logPath -Tail 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                }
                Write-Host ""
                Write-Host "  Press any key to return to main menu..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            { $_ -in @('0', 'Q') } {
                $running = $false
                Write-WinPilotLog -Level "INFO" -Component "Core" -Message "WinPilot session ended normally."
                Write-Host ""
                Write-Host "  Exiting WinPilot. Have a great day!" -ForegroundColor Green
                Write-Host ""
            }
        }
    }
}

Export-ModuleMember -Function @(
    "Start-WinPilot",
    "Get-WinPilotHost",
    "Test-WinPilotAdmin",
    "Initialize-WinPilotConsole",
    "Initialize-WinPilotLogger",
    "Get-WinPilotLogPath",
    "Write-WinPilotLog",
    "Get-WinPilotAnsiColor",
    "Clear-WinPilotScreen",
    "Show-WinPilotHeader",
    "Show-WinPilotBanner",
    "Format-WinPilotBox",
    "Read-WinPilotKey",
    "Read-WinPilotChoice",
    "Confirm-WinPilotAction",
    "Get-WinPilotFileHash",
    "Test-WinPilotFileIntegrity",
    "Test-WinPilotManifest",
    "Get-WinPilotSignature",
    "Test-WinPilotAuthenticode",
    "Invoke-WinPilotSecureStage"
)
