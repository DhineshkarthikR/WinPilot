<#
.SYNOPSIS
    WinPilot Root PowerShell Module Loader and Interactive Orchestrator.

.DESCRIPTION
    Loads core subsystem scripts, configures console settings, initializes
    audit logging, and provides the main interactive TUI navigation loop.
#>

$corePath = [System.IO.Path]::Combine($PSScriptRoot, "Core")
$securityPath = [System.IO.Path]::Combine($PSScriptRoot, "Security")
$diagPath = [System.IO.Path]::Combine($PSScriptRoot, "Modules", "Diagnostics")
$deployPath = [System.IO.Path]::Combine($PSScriptRoot, "Modules", "OfficeDeploy")

# Dot-source Core subsystem scripts in order
. (Join-Path $corePath "Host.ps1")
. (Join-Path $corePath "Logger.ps1")
. (Join-Path $corePath "AnsiUI.ps1")
. (Join-Path $corePath "Input.ps1")

# Dot-source Security subsystem scripts
. (Join-Path $securityPath "Integrity.ps1")
. (Join-Path $securityPath "SignatureVerifier.ps1")
. (Join-Path $securityPath "SecureBootstrapper.ps1")

# Dot-source Diagnostics subsystem scripts
. (Join-Path $diagPath "WindowsLicense.ps1")
. (Join-Path $diagPath "OfficeLicense.ps1")
. (Join-Path $diagPath "SystemHealth.ps1")

# Dot-source Office Deployment subsystem scripts
. (Join-Path $deployPath "OdtEngine.ps1")
. (Join-Path $deployPath "XmlBuilder.ps1")
. (Join-Path $deployPath "DeployRunner.ps1")

# Configure console and logging upon module import
Initialize-WinPilotConsole
Initialize-WinPilotLogger

function Show-WinPilotDiagnosticsMenu {
    <#
    .SYNOPSIS
        Displays the interactive diagnostics and auditing submenu.
    #>
    [CmdletBinding()]
    param()

    $diagRunning = $true
    while ($diagRunning) {
        Clear-WinPilotScreen
        Show-WinPilotHeader -Subtitle "Diagnostics & Licensing Auditing"

        $diagLines = @(
            " ",
            "  [1] Windows Activation & Licensing Audit  (CIM / SoftwareLicensingProduct)",
            "  [2] Perpetual Office Licensing Audit       (LTSC / Retail / Volume / MAK)",
            "  [3] Microsoft 365 Subscription Audit       (C2R / Channels / SCL / Tokens)",
            "  [4] System Specs & Component Store Health  (Hardware, Uptime, DISM)",
            "  [5] Run Complete Diagnostics Suite         (Execute All 4 Audits)",
            " ",
            "  [0] Return to Main Menu",
            " "
        )

        Format-WinPilotBox -Title "DIAGNOSTICS & AUDITING" -Lines $diagLines -Width 76
        Write-Host ""

        $diagChoice = Read-WinPilotChoice -ValidKeys @('1', '2', '3', '4', '5', '0', 'Q') -Prompt "  Select an audit [0-5]: "

        switch ($diagChoice) {
            '1' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Windows Licensing Audit"
                Show-WinPilotWindowsLicenseReport
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '2' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Perpetual Office Licensing Audit"
                $perps = Get-WinPilotOfficePerpetualStatus
                $perpLines = New-Object System.Collections.Generic.List[string]
                $perpLines.Add(" ")
                if ($perps.Count -eq 0) {
                    $perpLines.Add("  [No perpetual Office licenses (LTSC / Retail / MAK) detected in CIM]")
                }
                else {
                    foreach ($p in $perps) {
                        $perpLines.Add("  Product   : $($p.ProductName)")
                        $perpLines.Add("  Status    : $($p.LicenseStatusText) | Channel: $($p.LicensingChannel)")
                        $perpLines.Add("  Key (Last): $($p.PartialProductKey)")
                        $perpLines.Add(" ")
                    }
                }
                $perpLines.Add(" ")
                Format-WinPilotBox -Title "PERPETUAL OFFICE LICENSES" -Lines $perpLines.ToArray() -Width 76
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '3' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Microsoft 365 Subscription Audit"
                $sub = Get-WinPilotOfficeSubscriptionStatus
                $subLines = @(
                    " ",
                    "  C2R Installed       : $(if ($sub.IsClickToRunInstalled) { 'Yes' } else { 'No' })",
                    "  Products Detected   : $($sub.ProductReleaseIds)",
                    "  Version & Platform  : $($sub.Version) ($($sub.Architecture))",
                    "  Update Channel      : $($sub.UpdateChannel)",
                    "  Shared Computer Lic : $(if ($sub.SharedComputerLicensing) { 'Enabled (Multi-user)' } else { 'Disabled (Standard)' })",
                    "  Subscription Tokens : $(if ($sub.SubscriptionTokenCount -gt 0) { "Present ($($sub.SubscriptionTokenCount) tokens)" } else { 'None found' })",
                    "  CIM Subscription    : $($sub.CimSubscriptionName) ($($sub.CimSubscriptionStatus))",
                    " "
                )
                Format-WinPilotBox -Title "MICROSOFT 365 SUBSCRIPTION & C2R AUDIT" -Lines $subLines -Width 76
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '4' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "System Specifications & Store Health"
                Show-WinPilotSystemHealthReport
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '5' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Comprehensive Diagnostics Report"
                Show-WinPilotWindowsLicenseReport
                Write-Host ""
                Show-WinPilotOfficeLicenseReport
                Write-Host ""
                Show-WinPilotSystemHealthReport
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            { $_ -in @('0', 'Q') } {
                $diagRunning = $false
            }
        }
    }
}

function Show-WinPilotDeployMenu {
    <#
    .SYNOPSIS
        Displays the interactive Office Deployment Suite submenu.
    #>
    [CmdletBinding()]
    param()

    $deployRunning = $true
    while ($deployRunning) {
        Clear-WinPilotScreen
        Show-WinPilotHeader -Subtitle "Office Deployment Suite (Official Microsoft ODT)"

        $deployLines = @(
            " ",
            "  [1] Deploy Microsoft 365 Apps for Enterprise  (x64, Current Channel)",
            "  [2] Deploy Microsoft 365 Apps for Business    (x64, Current Channel)",
            "  [3] Deploy Office LTSC Professional Plus 2021 (Volume, x64)",
            "  [4] Deploy Office LTSC Professional Plus 2024 (Volume, x64)",
            "  [5] Download Office Deployment Tool Only      (Verify setup.exe)",
            "  [6] Download Office Installation Files Only   (/download mode)",
            " ",
            "  [0] Return to Main Menu",
            " "
        )

        Format-WinPilotBox -Title "OFFICE DEPLOYMENT SUITE" -Lines $deployLines -Width 76
        Write-Host ""

        $deployChoice = Read-WinPilotChoice -ValidKeys @('1', '2', '3', '4', '5', '6', '0', 'Q') -Prompt "  Select an action [0-6]: "

        $odtDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "ODT")
        $configPath = [System.IO.Path]::Combine($odtDir, "configuration.xml")

        switch ($deployChoice) {
            '1' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Deploy M365 Apps for Enterprise"
                New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -Architecture "64" -Channel "Current" -OutputPath $configPath | Out-Null
                Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath $configPath | Out-Null
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '2' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Deploy M365 Apps for Business"
                New-WinPilotOfficeXml -ProductId "O365BusinessRetail" -Architecture "64" -Channel "Current" -OutputPath $configPath | Out-Null
                Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath $configPath | Out-Null
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '3' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Deploy Office LTSC 2021"
                New-WinPilotOfficeXml -ProductId "ProPlus2021Volume" -Architecture "64" -Channel "PerpetualVL2021" -OutputPath $configPath | Out-Null
                Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath $configPath | Out-Null
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '4' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Deploy Office LTSC 2024"
                New-WinPilotOfficeXml -ProductId "ProPlus2024Volume" -Architecture "64" -Channel "PerpetualVL2024" -OutputPath $configPath | Out-Null
                Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath $configPath | Out-Null
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '5' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Download ODT Tool"
                Show-WinPilotBanner -Message "Acquiring and verifying official Microsoft ODT setup.exe..." -Type "Info"
                try {
                    $setup = Get-WinPilotOdt
                    Show-WinPilotBanner -Message "Verified setup.exe ready at: $setup" -Type "Success"
                }
                catch {
                    Show-WinPilotBanner -Message "Failed to acquire ODT: $($_.Exception.Message)" -Type "Error"
                }
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            '6' {
                Clear-WinPilotScreen
                Show-WinPilotHeader -Subtitle "Download Office Files (/download)"
                New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -Architecture "64" -Channel "Current" -OutputPath $configPath | Out-Null
                Show-WinPilotBanner -Message "Downloading Office installation streaming files to local cache..." -Type "Info"
                Invoke-WinPilotOfficeDeploy -Mode "Download" -ConfigurationPath $configPath | Out-Null
                Write-Host ""
                Write-Host "  Press any key to return..." -ForegroundColor Gray
                [void](Read-WinPilotKey)
            }
            { $_ -in @('0', 'Q') } {
                $deployRunning = $false
            }
        }
    }
}

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
                Show-WinPilotDiagnosticsMenu
            }
            '2' {
                Show-WinPilotDeployMenu
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
    "Invoke-WinPilotSecureStage",
    "Get-WinPilotWindowsLicense",
    "Show-WinPilotWindowsLicenseReport",
    "Get-WinPilotOfficePerpetualStatus",
    "Get-WinPilotOfficeSubscriptionStatus",
    "Show-WinPilotOfficeLicenseReport",
    "Get-WinPilotSystemHealth",
    "Test-WinPilotComponentStore",
    "Show-WinPilotSystemHealthReport",
    "Show-WinPilotDiagnosticsMenu",
    "Get-WinPilotOdt",
    "New-WinPilotOfficeXml",
    "Invoke-WinPilotOfficeDeploy",
    "Show-WinPilotDeployMenu"
)
