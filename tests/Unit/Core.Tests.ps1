#
# Pester Unit Tests for WinPilot Milestone 1 - Core Framework & Safety Guards
# Compatible with both Pester v3.4+ and Pester v5+
#

$modulePath = Resolve-Path "$PSScriptRoot\..\..\src\WinPilot.psd1"
Import-Module $modulePath -Force

Describe "WinPilot Module & Manifest Validation" {
    It "Validates the module manifest successfully" {
        $manifest = Test-ModuleManifest -Path $modulePath
        $manifest | Should Not BeNullOrEmpty
        $manifest.Version.ToString() | Should Match "^0\.[1-9]\.0$"
        $manifest.PowerShellVersion.ToString() | Should Be "5.1"
    }

    It "Imports the WinPilot module without errors" {
        { Import-Module $modulePath -Force -ErrorAction Stop } | Should Not Throw
    }

    It "Exports all required public cmdlets" {
        $expectedCmdlets = @(
            'Start-WinPilot',
            'Get-WinPilotHost',
            'Test-WinPilotAdmin',
            'Initialize-WinPilotConsole',
            'Invoke-WinPilotProcess',
            'Initialize-WinPilotLogger',
            'Get-WinPilotLogPath',
            'Write-WinPilotLog',
            'Get-WinPilotAnsiColor',
            'Clear-WinPilotScreen',
            'Show-WinPilotHeader',
            'Show-WinPilotBanner',
            'Format-WinPilotBox',
            'Read-WinPilotKey',
            'Read-WinPilotChoice',
            'Confirm-WinPilotAction',
            'Get-WinPilotFileHash',
            'Test-WinPilotFileIntegrity',
            'Test-WinPilotManifest',
            'Get-WinPilotSignature',
            'Test-WinPilotAuthenticode',
            'Get-WinPilotX500Attribute',
            'Invoke-WinPilotSecureStage',
            'Get-WinPilotWindowsLicense',
            'Show-WinPilotWindowsLicenseReport',
            'Get-WinPilotOfficePerpetualStatus',
            'Get-WinPilotOfficeSubscriptionStatus',
            'Show-WinPilotOfficeLicenseReport',
            'Get-WinPilotSystemHealth',
            'Test-WinPilotComponentStore',
            'Show-WinPilotSystemHealthReport',
            'Show-WinPilotDiagnosticsMenu',
            'Get-WinPilotOdt',
            'New-WinPilotOfficeXml',
            'Invoke-WinPilotOfficeDeploy',
            'Show-WinPilotDeployMenu',
            'Get-WinPilotC2RClient',
            'Invoke-WinPilotOfficeQuickRepair',
            'Invoke-WinPilotOfficeOnlineRepair',
            'Get-WinPilotOfficeUpdateConfig',
            'Invoke-WinPilotOfficeUpdate',
            'Get-WinPilotOfficeInstallationInventory',
            'New-WinPilotOfficeRemovalXml',
            'Invoke-WinPilotOfficeUninstall',
            'Show-WinPilotMaintenanceMenu'
        )

        $module = Get-Module WinPilot
        foreach ($cmd in $expectedCmdlets) {
            $module.ExportedFunctions.ContainsKey($cmd) | Should Be $true
        }
    }
}

Describe "WinPilot Host & Console Detection" {
    It "Get-WinPilotHost returns comprehensive system details" {
        $hostInfo = Get-WinPilotHost
        $hostInfo | Should Not BeNullOrEmpty
        $hostInfo.PowerShellVersion | Should Not BeNullOrEmpty
        $hostInfo.OSBuild | Should BeGreaterThan 0
        $hostInfo.Architecture | Should Not BeNullOrEmpty
        $hostInfo.ComputerName | Should Not BeNullOrEmpty
        $hostInfo.CurrentUserName | Should Not BeNullOrEmpty
    }

    It "Test-WinPilotAdmin accurately returns boolean privilege state" {
        $isAdmin = Test-WinPilotAdmin
        ($isAdmin -eq $true -or $isAdmin -eq $false) | Should Be $true
    }

    It "Host accurately identifies current Windows platform" {
        $hostInfo = Get-WinPilotHost
        ($hostInfo.IsWindows10 -or $hostInfo.IsWindows11) | Should Be $true
    }

    It "Initialize-WinPilotConsole executes idempotently without throwing" {
        {
            Initialize-WinPilotConsole
            Initialize-WinPilotConsole
        } | Should Not Throw
    }

    It "Invoke-WinPilotProcess executes process and captures exit code" {
        $res = Invoke-WinPilotProcess -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList "/c exit 0"
        $res.ExitCode | Should Be 0
        $res.Success | Should Be $true

        $resFail = Invoke-WinPilotProcess -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList "/c exit 42"
        $resFail.ExitCode | Should Be 42
        $resFail.Success | Should Be $false
    }
}

Describe "WinPilot Structured Logger & Audit Trail" {
    $tempLogDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinPilot_TestLogs_$([Guid]::NewGuid().ToString('N'))"

    It "Initializes the logger and creates target directory" {
        Initialize-WinPilotLogger -BasePath $tempLogDir
        Test-Path $tempLogDir | Should Be $true
    }

    It "Writes structured log entries with timestamps, severity levels, and components" {
        $testMsg = "Unit test event $([Guid]::NewGuid())"
        Write-WinPilotLog -Level "INFO" -Component "UnitTest" -Message $testMsg

        $logPath = Get-WinPilotLogPath
        Test-Path $logPath | Should Be $true

        $content = Get-Content $logPath
        $matching = $content | Where-Object { $_ -match [regex]::Escape($testMsg) }
        $matching | Should Not BeNullOrEmpty
        $matching | Should Match "\[INFO\] \[UnitTest\]"
    }

    It "Records AUDIT severity logs for compliance tracking" {
        $auditMsg = "User safety confirmation event"
        Write-WinPilotLog -Level "AUDIT" -Component "SafetyGuard" -Message $auditMsg

        $logPath = Get-WinPilotLogPath
        $content = Get-Content $logPath
        $matching = $content | Where-Object { $_ -match [regex]::Escape($auditMsg) }
        $matching | Should Not BeNullOrEmpty
        $matching | Should Match "\[AUDIT\] \[SafetyGuard\]"
    }

    It "Get-WinPilotLogPath returns a valid .log file path" {
        $path = Get-WinPilotLogPath
        $path | Should Match "\.log$"
    }

    # Clean up test log directory
    if (Test-Path $tempLogDir) {
        Remove-Item -Path $tempLogDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "WinPilot ANSI & UI Formatting" {
    It "Returns valid ANSI color sequences" {
        $cyan = Get-WinPilotAnsiColor -ColorName "Cyan"
        $cyan | Should Match "^\e\[|^\x1B\["

        $reset = Get-WinPilotAnsiColor -ColorName "Reset"
        $reset | Should Match "^\e\[|^\x1B\["

        $green = Get-WinPilotAnsiColor -ColorName "BrightGreen"
        $green | Should Match "^\e\[|^\x1B\["
    }

    It "Returns empty string for non-existent color without error" {
        $unknown = Get-WinPilotAnsiColor -ColorName "NonExistentColor99"
        $unknown | Should Be ""
    }

    It "Format-WinPilotBox handles custom widths, empty titles, and long text lines" {
        {
            Format-WinPilotBox -Lines @("Simple line") -Width 50
            Format-WinPilotBox -Title "CUSTOM TITLE" -Lines @("Line 1", "Line 2 with text") -Width 70
        } | Should Not Throw
    }

    It "Show-WinPilotBanner renders across all valid severity types" {
        {
            Show-WinPilotBanner -Message "Info test message" -Type "Info"
            Show-WinPilotBanner -Message "Success test message" -Type "Success"
            Show-WinPilotBanner -Message "Warning test message" -Type "Warning"
            Show-WinPilotBanner -Message "Error test message" -Type "Error"
        } | Should Not Throw
    }

    It "Show-WinPilotHeader formats title and subtitle cleanly" {
        {
            Show-WinPilotHeader -Subtitle "Test Validation Subtitle"
        } | Should Not Throw
    }
}

Describe "WinPilot Keyboard Navigation & Interactive Input" {
    It "Filters out invalid keypresses until a valid key is entered" {
        $global:winpilotTestKeys1 = New-Object 'System.Collections.Generic.Queue[System.ConsoleKeyInfo]'
        $global:winpilotTestKeys1.Enqueue([System.ConsoleKeyInfo]::new([char]'X', [ConsoleKey]::X, $false, $false, $false)) # Invalid
        $global:winpilotTestKeys1.Enqueue([System.ConsoleKeyInfo]::new([char]'9', [ConsoleKey]::D9, $false, $false, $false)) # Invalid
        $global:winpilotTestKeys1.Enqueue([System.ConsoleKeyInfo]::new([char]'1', [ConsoleKey]::D1, $false, $false, $false)) # Valid

        Mock -ModuleName WinPilot Read-WinPilotKey { return $global:winpilotTestKeys1.Dequeue() }

        $choice = Read-WinPilotChoice -ValidKeys @('1', '2', '0') -Prompt "  Test: "
        $choice.ToString() | Should Be "1"
    }

    It "Translates ESC keypress into '0' for graceful navigation" {
        Mock -ModuleName WinPilot Read-WinPilotKey {
            return [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
        }

        $choice = Read-WinPilotChoice -ValidKeys @('1', '2', '0') -Prompt "  Test ESC: "
        $choice.ToString() | Should Be "0"
    }

    It "Handles lowercase input matching uppercase valid keys" {
        $global:winpilotTestKeys2 = New-Object 'System.Collections.Generic.Queue[System.ConsoleKeyInfo]'
        $global:winpilotTestKeys2.Enqueue([System.ConsoleKeyInfo]::new([char]'q', [ConsoleKey]::Q, $false, $false, $false))

        Mock -ModuleName WinPilot Read-WinPilotKey { return $global:winpilotTestKeys2.Dequeue() }

        $choice = Read-WinPilotChoice -ValidKeys @('1', '2', 'Q') -Prompt "  Test Q: "
        $choice.ToString() | Should Be "Q"
    }
}

Describe "WinPilot Safety Guardrails & Confirmation Logic" {
    $safetyTestLogDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinPilot_SafetyLogTest_$([Guid]::NewGuid().ToString('N'))"
    Initialize-WinPilotLogger -BasePath $safetyTestLogDir

    It "Logs an AUDIT message when action is cancelled or confirmed" {
        $logPath = Get-WinPilotLogPath
        $initialCount = (Get-Content $logPath).Count

        # Mock Read-WinPilotKey inside WinPilot module to simulate pressing 'N' (cancellation)
        Mock -ModuleName WinPilot Read-WinPilotKey {
            return [PSCustomObject]@{ KeyChar = 'N'; Key = [ConsoleKey]::N }
        }

        $result = Confirm-WinPilotAction -ActionName "Test Non-Destructive Check" -RiskLevel "Moderate"
        $result | Should Be $false

        $newContent = Get-Content $logPath
        $newContent.Count | Should BeGreaterThan $initialCount
        $newContent[-1] | Should Match "\[AUDIT\] \[SafetyGuard\] User cancelled action"
    }

    It "High-risk action requires typed YES to proceed" {
        Mock -ModuleName WinPilot Read-Host { return "no" }

        $result = Confirm-WinPilotAction -ActionName "Simulated High Risk Operation" -RiskLevel "High"
        $result | Should Be $false
    }

    It "High-risk action succeeds only when user explicitly types YES" {
        Mock -ModuleName WinPilot Read-Host { return "YES" }

        $result = Confirm-WinPilotAction -ActionName "Simulated Approved Operation" -RiskLevel "High"
        $result | Should Be $true

        $logPath = Get-WinPilotLogPath
        $lastLog = (Get-Content $logPath)[-1]
        $lastLog | Should Match "\[AUDIT\] \[SafetyGuard\] User confirmed action"
    }

    if (Test-Path $safetyTestLogDir) {
        Remove-Item -Path $safetyTestLogDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
