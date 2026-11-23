#
# Pester Unit Tests for WinPilot Milestone 4 - Office Maintenance Subsystem
# Compatible with PowerShell 5.1 and modern PowerShell
#

$modulePath = Resolve-Path "$PSScriptRoot\..\..\src\WinPilot.psd1"
Import-Module $modulePath -Force

Describe "WinPilot Office Repair Subsystem" {
    It "Get-WinPilotC2RClient executes without throwing" {
        {
            $c2r = Get-WinPilotC2RClient
            if ($c2r) {
                ($c2r -is [string]) | Should Be $true
            }
        } | Should Not Throw
    }

    It "Quick Repair guides user and launches supported Windows repair interface" {
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{ IsInstalled = $true }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Start-Process { }

        $res = Invoke-WinPilotOfficeQuickRepair
        $res.Success | Should Be $true
        $res.Launched | Should Be $true
        $res.Completed | Should Be "External"
        $res.StatusMessage | Should Match "launched successfully"
    }

    It "Quick Repair halts gracefully when cancelled by user" {
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{ IsInstalled = $true }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeQuickRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $false
        $res.ExitCode | Should Be -1
        $res.StatusMessage | Should Match "cancelled"
    }

    It "Quick Repair handles missing Office installation gracefully" {
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{ IsInstalled = $false }
        }

        $res = Invoke-WinPilotOfficeQuickRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $false
        $res.StatusMessage | Should Match "not found"
    }

    It "Rejects candidate binary when OriginalFilename does not match OfficeClickToRun.exe" {
        $fakeExe = [System.IO.Path]::GetTempFileName()
        try {
            Mock -ModuleName WinPilot Get-ItemProperty {
                return @(
                    [PSCustomObject]@{
                        DisplayName = "Microsoft 365 Apps"
                        ModifyPath  = "`"$fakeExe`""
                    }
                )
            }
            Mock -ModuleName WinPilot Test-Path { return $true }
            Mock -ModuleName WinPilot Test-WinPilotAuthenticode { return $true }
            Mock -ModuleName WinPilot Get-Item {
                return [PSCustomObject]@{
                    VersionInfo = [PSCustomObject]@{
                        OriginalFilename = "notepad.exe"
                        FileDescription  = "Microsoft Office Click-to-Run"
                    }
                }
            }

            $client = Get-WinPilotC2RClient
            $client | Should BeNullOrEmpty
        }
        finally {
            if (Test-Path $fakeExe) { Remove-Item $fakeExe -Force }
        }
    }

    It "Online Repair aborts when session lacks administrator privileges" {
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $false }

        $res = Invoke-WinPilotOfficeOnlineRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $false
        $res.ExitCode | Should Be -1
        $res.StatusMessage | Should Match "Administrator privileges required"
    }

    It "Online Repair fails cleanly when Office architecture cannot be determined" {
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $true }
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" }
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{
                IsInstalled       = $true
                Platform          = $null
                Languages         = @("en-us")
                ProductReleaseIds = @("O365ProPlusRetail")
                Version           = "16.0.1.1"
                UpdateChannel     = "Current"
            }
        }

        $res = Invoke-WinPilotOfficeOnlineRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $false
        $res.ExitCode | Should Be -1
        $res.StatusMessage | Should Match "architecture could not be determined"
    }

    It "Online Repair requires high-risk confirmation and halts if cancelled" {
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $true }
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" }
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{
                IsInstalled       = $true
                Platform          = "x64"
                Languages         = @("en-us")
                ProductReleaseIds = @("O365ProPlusRetail")
                Version           = "16.0.1.1"
                UpdateChannel     = "Current"
            }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeOnlineRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $false
        $res.StatusMessage | Should Match "cancelled"
    }

    It "Online Repair records pre-operation state" {
        $logPath = Get-WinPilotLogPath
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $true }
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" }
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{
                IsInstalled       = $true
                Platform          = "x64"
                Languages         = @("en-us")
                ProductReleaseIds = @("O365ProPlusRetail")
                Version           = "16.0.1.1"
                UpdateChannel     = "Current"
            }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        Invoke-WinPilotOfficeOnlineRepair | Out-Null

        $logs = Get-Content $logPath
        $matching = $logs | Where-Object { $_ -match "Pre-OnlineRepair state:" }
        $matching | Should Not BeNullOrEmpty
    }

    It "Online Repair handles non-zero exit codes as failure" {
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $true }
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" }
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{
                IsInstalled       = $true
                Platform          = "x64"
                Languages         = @("en-us")
                ProductReleaseIds = @("O365ProPlusRetail")
                Version           = "16.0.1.1"
                UpdateChannel     = "Current"
            }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Invoke-WinPilotProcess {
            param($FilePath, $ArgumentList)
            return [PSCustomObject]@{ ExitCode = 1; Success = $false }
        }

        $res = Invoke-WinPilotOfficeOnlineRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $true
        $res.ExitCode | Should Be 1
        $res.StatusMessage | Should Match "exited with code:"
    }

    It "Online Repair captures execution exception gracefully" {
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $true }
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" }
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{
                IsInstalled       = $true
                Platform          = "x64"
                Languages         = @("en-us")
                ProductReleaseIds = @("O365ProPlusRetail")
                Version           = "16.0.1.1"
                UpdateChannel     = "Current"
            }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Invoke-WinPilotProcess {
            param($FilePath, $ArgumentList)
            throw "Simulated execution error"
        }

        $res = Invoke-WinPilotOfficeOnlineRepair
        $res.Success | Should Be $false
        $res.Launched | Should Be $false
        $res.ExitCode | Should Be -1
        $res.StatusMessage | Should Match "exception:"
    }

    It "Online Repair invokes exact OfficeClickToRun executable and documented arguments without culture" {
        Mock -ModuleName WinPilot Test-WinPilotAdmin { return $true }
        Mock -ModuleName WinPilot Get-WinPilotC2RClient {
            return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
        }
        Mock -ModuleName WinPilot Get-WinPilotOfficeInstallationInventory {
            return [PSCustomObject]@{
                IsInstalled       = $true
                Platform          = "x64"
                Languages         = @("en-us")
                ProductReleaseIds = @("O365ProPlusRetail")
                Version           = "16.0.1.1"
                UpdateChannel     = "Current"
            }
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }

        $global:repairExe = $null
        $global:repairArgs = $null
        Mock -ModuleName WinPilot Invoke-WinPilotProcess {
            param($FilePath, $ArgumentList)
            $global:repairExe = $FilePath
            $global:repairArgs = $ArgumentList
            return [PSCustomObject]@{ ExitCode = 0; Success = $true }
        }

        try {
            $res = Invoke-WinPilotOfficeOnlineRepair
            $res.Success | Should Be $true
            $res.ExitCode | Should Be 0
            $global:repairExe | Should Be "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
            $global:repairArgs | Should Be "scenario=Repair platform=x64 RepairType=FullRepair DisplayLevel=True forceappshutdown=True"
            $global:repairArgs | Should Not Match "culture="
        }
        finally {
            $global:repairExe = $null
            $global:repairArgs = $null
        }
    }
}

Describe "WinPilot Office Update Subsystem" {
    It "Get-WinPilotOfficeUpdateConfig returns expected properties" {
        $config = Get-WinPilotOfficeUpdateConfig
        $config | Should Not BeNullOrEmpty
        ($config.IsInstalled -eq $true -or $config.IsInstalled -eq $false) | Should Be $true
        $config.Version | Should Not BeNullOrEmpty
        $config.UpdateChannel | Should Not BeNullOrEmpty
        ($config.UpdatesEnabled -eq $true -or $config.UpdatesEnabled -eq $false) | Should Be $true
    }

    It "Update trigger halts safely when user aborts confirmation" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeUpdate
        $res.Success | Should Be $false
        $res.StatusMessage | Should Match "cancelled"
    }

    It "Update trigger distinguishes client launch from update completion" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Invoke-WinPilotProcess {
            param($FilePath, $ArgumentList)
            return [PSCustomObject]@{ ExitCode = 0; Success = $true }
        }

        $res = Invoke-WinPilotOfficeUpdate
        $res | Get-Member -Name "Triggered" | Should Not BeNullOrEmpty
        $res.Triggered | Should Be $true
    }

    It "Update trigger captures non-zero exit codes as failure" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Invoke-WinPilotProcess {
            param($FilePath, $ArgumentList)
            return [PSCustomObject]@{ ExitCode = 2; Success = $false }
        }

        $res = Invoke-WinPilotOfficeUpdate
        $res.Success | Should Be $false
        $res.ExitCode | Should Be 2
    }

    It "Office Update invokes exact OfficeC2RClient executable and documented update arguments" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient {
            return "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }

        $global:updateExe = $null
        $global:updateArgs = $null
        Mock -ModuleName WinPilot Invoke-WinPilotProcess {
            param($FilePath, $ArgumentList)
            $global:updateExe = $FilePath
            $global:updateArgs = $ArgumentList
            return [PSCustomObject]@{ ExitCode = 0; Success = $true }
        }

        try {
            $res = Invoke-WinPilotOfficeUpdate
            $res.Success | Should Be $true
            $res.ExitCode | Should Be 0
            $global:updateExe | Should Be "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
            $global:updateArgs | Should Be "/update user displaylevel=true"
        }
        finally {
            $global:updateExe = $null
            $global:updateArgs = $null
        }
    }
}

Describe "WinPilot Office Installation Inventory" {
    It "Get-WinPilotOfficeInstallationInventory returns expected schema properties" {
        $inv = Get-WinPilotOfficeInstallationInventory
        $inv | Should Not BeNullOrEmpty
        ($inv.IsInstalled -eq $true -or $inv.IsInstalled -eq $false) | Should Be $true
        if ($inv.IsInstalled) {
            $inv.ProductReleaseIds | Should Not BeNullOrEmpty
            $inv.Languages | Should Not BeNullOrEmpty
        }
        else {
            $inv.ProductReleaseIds -is [System.Array] | Should Be $true
            $inv.Languages -is [System.Array] | Should Be $true
        }
        $inv.Platform | Should Not BeNullOrEmpty
        $inv.Version | Should Not BeNullOrEmpty
    }
}

Describe "WinPilot Office Removal XML Generator" {
    It "Generates valid well-formed XML with <Remove All='TRUE' /> by default" {
        $xmlStr = New-WinPilotOfficeRemovalXml
        $xmlStr | Should Not BeNullOrEmpty

        $doc = New-Object System.Xml.XmlDocument
        { $doc.LoadXml($xmlStr) } | Should Not Throw

        $remNode = $doc.SelectSingleNode("/Configuration/Remove")
        $remNode | Should Not BeNullOrEmpty
        $remNode.GetAttribute("All") | Should Be "TRUE"

        $dispNode = $doc.SelectSingleNode("/Configuration/Display")
        $dispNode.GetAttribute("AcceptEULA") | Should Be "TRUE"
    }

    It "Generates selective removal XML when specific ProductIds are provided" {
        $xmlStr = New-WinPilotOfficeRemovalXml -ProductIds @("O365ProPlusRetail", "VisioPro2021Volume")
        $doc = New-Object System.Xml.XmlDocument
        $doc.LoadXml($xmlStr)

        $remNode = $doc.SelectSingleNode("/Configuration/Remove")
        $remNode.GetAttribute("All") | Should Be ""

        $prodNodes = $doc.SelectNodes("/Configuration/Remove/Product")
        $prodNodes.Count | Should Be 2
        $prodNodes[0].GetAttribute("ID") | Should Be "O365ProPlusRetail"
        $prodNodes[1].GetAttribute("ID") | Should Be "VisioPro2021Volume"
    }

    It "Writes removal XML to disk when OutputPath is specified" {
        $tempXml = [System.IO.Path]::GetTempFileName()
        try {
            $xmlStr = New-WinPilotOfficeRemovalXml -OutputPath $tempXml
            Test-Path -Path $tempXml | Should Be $true

            $diskContent = [System.IO.File]::ReadAllText($tempXml, [System.Text.Encoding]::UTF8)
            $diskContent | Should Match "<Remove"
        }
        finally {
            if (Test-Path $tempXml) { Remove-Item $tempXml -Force }
        }
    }
}

Describe "WinPilot Office Uninstallation Execution & Safety Guardrails" {
    It "Halts uninstallation safely when user cancels critical confirmation" {
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Fake Binary", [System.Text.Encoding]::UTF8)

        Mock -ModuleName WinPilot Test-WinPilotAuthenticode { return $true }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        try {
            $res = Invoke-WinPilotOfficeUninstall -SetupPath $fakeSetup
            $res.Success | Should Be $false
            $res.ExitCode | Should Be -1
            $res.StatusMessage | Should Match "cancelled"
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }

    It "Logs pre-uninstall audit state prior to execution prompt" {
        $logPath = Get-WinPilotLogPath
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Fake Binary", [System.Text.Encoding]::UTF8)

        Mock -ModuleName WinPilot Test-WinPilotAuthenticode { return $true }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        try {
            Invoke-WinPilotOfficeUninstall -SetupPath $fakeSetup | Out-Null

            $logs = Get-Content $logPath
            $matching = $logs | Where-Object { $_ -match "\[AUDIT\] \[OfficeUninstall\] Pre-Uninstall State:" }
            $matching | Should Not BeNullOrEmpty
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }

    It "Rejects unverified or unsigned setup binaries for uninstallation" {
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Unsigned binary", [System.Text.Encoding]::UTF8)

        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Test-WinPilotAuthenticode { return $false }

        try {
            {
                Invoke-WinPilotOfficeUninstall -SetupPath $fakeSetup
            } | Should Throw
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }

    It "Cleans up temporary removal XML even if setup execution encounters an exception" {
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Fake Binary", [System.Text.Encoding]::UTF8)

        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Test-WinPilotAuthenticode { return $true }
        Mock -ModuleName WinPilot Invoke-WinPilotProcess { throw "Simulated process failure" }

        $odtTempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "ODT")
        $initialXmlCount = if (Test-Path $odtTempDir) { (Get-ChildItem -Path $odtTempDir -Filter "remove_config_*.xml").Count } else { 0 }

        try {
            $res = Invoke-WinPilotOfficeUninstall -SetupPath $fakeSetup
            $res.Success | Should Be $false
            $res.StatusMessage | Should Match "Uninstallation failed:"

            $finalXmlCount = if (Test-Path $odtTempDir) { (Get-ChildItem -Path $odtTempDir -Filter "remove_config_*.xml").Count } else { 0 }
            $finalXmlCount | Should Be $initialXmlCount
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }

    It "Cleans up temporary removal XML if XML creation throws an exception" {
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Fake Binary", [System.Text.Encoding]::UTF8)

        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }
        Mock -ModuleName WinPilot Test-WinPilotAuthenticode { return $true }
        Mock -ModuleName WinPilot New-WinPilotOfficeRemovalXml { throw "Simulated XML generation failure" }

        $odtTempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "ODT")
        $initialXmlCount = if (Test-Path $odtTempDir) { (Get-ChildItem -Path $odtTempDir -Filter "remove_config_*.xml").Count } else { 0 }

        try {
            $res = Invoke-WinPilotOfficeUninstall -SetupPath $fakeSetup
            $res.Success | Should Be $false
            $res.StatusMessage | Should Match "Uninstallation failed: Simulated XML generation failure"

            $finalXmlCount = if (Test-Path $odtTempDir) { (Get-ChildItem -Path $odtTempDir -Filter "remove_config_*.xml").Count } else { 0 }
            $finalXmlCount | Should Be $initialXmlCount
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }
}
