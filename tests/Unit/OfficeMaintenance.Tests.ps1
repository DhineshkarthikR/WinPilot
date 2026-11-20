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

    It "Quick Repair halts gracefully when cancelled by user" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "$env:SystemRoot\System32\notepad.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeQuickRepair
        $res.Success | Should Be $false
        $res.ExitCode | Should Be -1
        $res.StatusMessage | Should Match "cancelled"
    }

    It "Quick Repair handles missing C2R client gracefully" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return $null }

        $res = Invoke-WinPilotOfficeQuickRepair
        $res.Success | Should Be $false
        $res.StatusMessage | Should Match "not found"
    }

    It "Online Repair requires high-risk confirmation and halts if cancelled" {
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "$env:SystemRoot\System32\notepad.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeOnlineRepair
        $res.Success | Should Be $false
        $res.StatusMessage | Should Match "cancelled"
    }

    It "Online Repair records pre-operation state" {
        $logPath = Get-WinPilotLogPath
        $initialCount = (Get-Content $logPath).Count

        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "$env:SystemRoot\System32\notepad.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        Invoke-WinPilotOfficeOnlineRepair | Out-Null

        $logs = Get-Content $logPath
        $matching = $logs | Where-Object { $_ -match "Pre-OnlineRepair state:" }
        $matching | Should Not BeNullOrEmpty
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
        Mock -ModuleName WinPilot Get-WinPilotC2RClient { return "$env:SystemRoot\System32\notepad.exe" }
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeUpdate
        $res.Success | Should Be $false
        $res.StatusMessage | Should Match "cancelled"
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
        $validMsBinary = "$env:SystemRoot\System32\notepad.exe"
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        $res = Invoke-WinPilotOfficeUninstall -SetupPath $validMsBinary
        $res.Success | Should Be $false
        $res.ExitCode | Should Be -1
        $res.StatusMessage | Should Match "cancelled"
    }

    It "Logs pre-uninstall audit state prior to execution prompt" {
        $logPath = Get-WinPilotLogPath
        $validMsBinary = "$env:SystemRoot\System32\notepad.exe"
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        Invoke-WinPilotOfficeUninstall -SetupPath $validMsBinary | Out-Null

        $logs = Get-Content $logPath
        $matching = $logs | Where-Object { $_ -match "\[AUDIT\] \[OfficeUninstall\] Pre-Uninstall State:" }
        $matching | Should Not BeNullOrEmpty
    }

    It "Rejects unverified or unsigned setup binaries for uninstallation" {
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Unsigned binary", [System.Text.Encoding]::UTF8)

        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }

        try {
            {
                Invoke-WinPilotOfficeUninstall -SetupPath $fakeSetup
            } | Should Throw
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }
}
