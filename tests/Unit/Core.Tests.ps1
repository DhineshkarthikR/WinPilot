#
# Pester Unit Tests for WinPilot Milestone 1 - Core Framework
# Compatible with both Pester v3.4+ and Pester v5+
#

$modulePath = Resolve-Path "$PSScriptRoot\..\..\src\WinPilot.psd1"

Describe "WinPilot Module & Scaffold" {
    It "Validates the module manifest successfully" {
        $manifest = Test-ModuleManifest -Path $modulePath
        $manifest | Should Not BeNullOrEmpty
        $manifest.Version.ToString() | Should Be "0.1.0"
        $manifest.PowerShellVersion.ToString() | Should Be "5.1"
    }

    It "Imports the WinPilot module without errors" {
        { Import-Module $modulePath -Force -ErrorAction Stop } | Should Not Throw
    }
}

Describe "WinPilot Core Host Detection" {
    It "Get-WinPilotHost returns expected environment schema" {
        $hostInfo = Get-WinPilotHost
        $hostInfo | Should Not BeNullOrEmpty
        $hostInfo.PowerShellVersion | Should Not BeNullOrEmpty
        $hostInfo.OSBuild | Should BeGreaterThan 0
        $hostInfo.Architecture | Should Not BeNullOrEmpty
    }

    It "Test-WinPilotAdmin returns a boolean value" {
        $isAdmin = Test-WinPilotAdmin
        ($isAdmin -eq $true -or $isAdmin -eq $false) | Should Be $true
    }

    It "Host recognizes Windows environment" {
        $hostInfo = Get-WinPilotHost
        ($hostInfo.IsWindows10 -or $hostInfo.IsWindows11) | Should Be $true
    }
}

Describe "WinPilot Structured Logger" {
    $tempLogDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinPilot_TestLogs_$([Guid]::NewGuid().ToString('N'))"

    It "Initializes the logger and creates log directory" {
        Initialize-WinPilotLogger -BasePath $tempLogDir
        Test-Path $tempLogDir | Should Be $true
    }

    It "Writes structured log entries to file with timestamps and levels" {
        $testMsg = "Unit test event $([Guid]::NewGuid())"
        Write-WinPilotLog -Level "INFO" -Component "UnitTest" -Message $testMsg

        $logPath = Get-WinPilotLogPath
        Test-Path $logPath | Should Be $true

        $content = Get-Content $logPath
        $matching = $content | Where-Object { $_ -match [regex]::Escape($testMsg) }
        $matching | Should Not BeNullOrEmpty
        $matching | Should Match "\[INFO\] \[UnitTest\]"
    }

    It "Supports AUDIT level logging" {
        $auditMsg = "User audit action test"
        Write-WinPilotLog -Level "AUDIT" -Component "Security" -Message $auditMsg

        $logPath = Get-WinPilotLogPath
        $content = Get-Content $logPath
        $matching = $content | Where-Object { $_ -match [regex]::Escape($auditMsg) }
        $matching | Should Not BeNullOrEmpty
        $matching | Should Match "\[AUDIT\] \[Security\]"
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
    }

    It "Returns empty string for non-existent color without error" {
        $unknown = Get-WinPilotAnsiColor -ColorName "FakeColor123"
        $unknown | Should Be ""
    }

    It "Format-WinPilotBox executes without errors" {
        {
            Format-WinPilotBox -Title "TEST BOX" -Lines @("Line 1", "Line 2") -Width 60
        } | Should Not Throw
    }

    It "Show-WinPilotBanner executes for all supported types without errors" {
        {
            Show-WinPilotBanner -Message "Info test" -Type "Info"
            Show-WinPilotBanner -Message "Success test" -Type "Success"
            Show-WinPilotBanner -Message "Warning test" -Type "Warning"
            Show-WinPilotBanner -Message "Error test" -Type "Error"
        } | Should Not Throw
    }
}
