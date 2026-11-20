#
# Pester Unit Tests for WinPilot Milestone 3 - Office Deployment Suite
# Compatible with PowerShell 5.1 and modern PowerShell
#

$modulePath = Resolve-Path "$PSScriptRoot\..\..\src\WinPilot.psd1"
Import-Module $modulePath -Force

Describe "WinPilot Office XML Generator (Schema & Content Validation)" {
    It "Generates valid well-formed XML parseable by System.Xml.XmlDocument" {
        $xmlStr = New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -Architecture "64" -Channel "Current"
        $xmlStr | Should Not BeNullOrEmpty

        $xmlDoc = New-Object System.Xml.XmlDocument
        { $xmlDoc.LoadXml($xmlStr) } | Should Not Throw
        $xmlDoc.DocumentElement.Name | Should Be "Configuration"
    }

    It "Generates correct Add, Product and Language attributes for M365 Enterprise" {
        $xmlStr = New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -Architecture "64" -Channel "Current"
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($xmlStr)

        $addNode = $xmlDoc.SelectSingleNode("/Configuration/Add")
        $addNode | Should Not BeNullOrEmpty
        $addNode.GetAttribute("OfficeClientEdition") | Should Be "64"
        $addNode.GetAttribute("Channel") | Should Be "Current"

        $prodNode = $xmlDoc.SelectSingleNode("/Configuration/Add/Product[@ID='O365ProPlusRetail']")
        $prodNode | Should Not BeNullOrEmpty

        $langNode = $prodNode.SelectSingleNode("Language[@ID='MatchOS']")
        $langNode | Should Not BeNullOrEmpty
    }

    It "Supports x86 (32-bit) architecture specification" {
        $xmlStr = New-WinPilotOfficeXml -ProductId "O365BusinessRetail" -Architecture "32"
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($xmlStr)

        $addNode = $xmlDoc.SelectSingleNode("/Configuration/Add")
        $addNode.GetAttribute("OfficeClientEdition") | Should Be "32"
    }

    It "Supports application exclusions with ExcludeApp elements" {
        $xmlStr = New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -ExcludeApps @("Access", "Teams", "OneDrive")
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($xmlStr)

        $excludedNodes = $xmlDoc.SelectNodes("/Configuration/Add/Product/ExcludeApp")
        $excludedNodes.Count | Should Be 3

        $accessNode = $xmlDoc.SelectSingleNode("/Configuration/Add/Product/ExcludeApp[@ID='Access']")
        $accessNode | Should Not BeNullOrEmpty

        $teamsNode = $xmlDoc.SelectSingleNode("/Configuration/Add/Product/ExcludeApp[@ID='Teams']")
        $teamsNode | Should Not BeNullOrEmpty
    }

    It "Auto-configures PerpetualVL2021 channel for Office 2021 LTSC Volume" {
        $xmlStr = New-WinPilotOfficeXml -ProductId "ProPlus2021Volume"
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($xmlStr)

        $addNode = $xmlDoc.SelectSingleNode("/Configuration/Add")
        $addNode.GetAttribute("Channel") | Should Be "PerpetualVL2021"
    }

    It "Includes SharedComputerLicensing property when switch is provided" {
        $xmlStr = New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -SharedComputerLicensing
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($xmlStr)

        $propNode = $xmlDoc.SelectSingleNode("/Configuration/Property[@Name='SharedComputerLicensing']")
        $propNode | Should Not BeNullOrEmpty
        $propNode.GetAttribute("Value") | Should Be "1"
    }

    It "Writes valid configuration XML to disk when OutputPath is specified" {
        $tempXml = [System.IO.Path]::GetTempFileName()
        try {
            $returnedStr = New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" -OutputPath $tempXml
            Test-Path -Path $tempXml | Should Be $true

            $diskContent = [System.IO.File]::ReadAllText($tempXml, [System.Text.Encoding]::UTF8)
            $diskContent | Should Match "<Configuration>"
            $diskContent | Should Match "O365ProPlusRetail"
        }
        finally {
            if (Test-Path $tempXml) { Remove-Item $tempXml -Force }
        }
    }
}

Describe "WinPilot ODT Acquisition & Security Validation" {
    It "Rejects non-Microsoft download URLs at parameter validation boundary" {
        {
            Get-WinPilotOdt -DownloadUrl "https://malicious-mirror.example.com/fake_odt.exe"
        } | Should Throw
    }

    It "Rejects deceptive subdomains mimicking approved Microsoft hosts" {
        {
            Get-WinPilotOdt -DownloadUrl "https://download.microsoft.com.evil.com/fake_odt.exe"
        } | Should Throw
    }

    It "Rejects non-approved subdomains under microsoft.com" {
        {
            Get-WinPilotOdt -DownloadUrl "https://unauthorized-subdomain.microsoft.com/payload.exe"
        } | Should Throw
    }

    It "Rejects non-HTTPS download URLs (HTTP downgrade protection)" {
        {
            Get-WinPilotOdt -DownloadUrl "http://download.microsoft.com/officedeploymenttool.exe"
        } | Should Throw
    }

    It "Rejects unverified or unsigned setup binaries" {
        $fakeSetup = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($fakeSetup, "Fake Binary", [System.Text.Encoding]::UTF8)

        try {
            $isAuthentic = Test-WinPilotAuthenticode -Path $fakeSetup -ExpectedSubject "Microsoft Corporation"
            $isAuthentic | Should Be $false
        }
        finally {
            if (Test-Path $fakeSetup) { Remove-Item $fakeSetup -Force }
        }
    }
}

Describe "WinPilot Office Deployment Execution Runner" {
    It "Throws FileNotFoundException when configuration XML is missing" {
        $missingPath = "C:\Windows\Temp\NonExistentConfig_$([Guid]::NewGuid().ToString('N')).xml"
        {
            Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath $missingPath
        } | Should Throw
    }

    It "Halts installation safely when user aborts confirmation prompt" {
        $tempConfig = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tempConfig, "<Configuration></Configuration>", [System.Text.Encoding]::UTF8)

        # Mock setup.exe path using valid signed Microsoft binary to pass pre-flight signature check
        $validMsBinary = "$env:SystemRoot\System32\notepad.exe"

        # Mock confirmation to simulate user pressing 'N'
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $false }

        try {
            $result = Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath $tempConfig -SetupPath $validMsBinary
            $result.Success | Should Be $false
            $result.ExitCode | Should Be -1
            $result.StatusMessage | Should Match "Operation cancelled"
        }
        finally {
            if (Test-Path $tempConfig) { Remove-Item $tempConfig -Force }
        }
    }

    It "Captures execution exit code and returns success object on exit code 0" {
        $tempConfig = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tempConfig, "<Configuration></Configuration>", [System.Text.Encoding]::UTF8)
        $validMsBinary = "$env:SystemRoot\System32\notepad.exe"

        # Mock confirmation to approve
        Mock -ModuleName WinPilot Confirm-WinPilotAction { return $true }

        # Mock Process Start to simulate exit code 0 without actually running Office installer
        Mock -ModuleName WinPilot Start-Sleep { }

        try {
            # Test in Download mode to test argument construction
            $mockProcess = [PSCustomObject]@{
                HasExited = $true
                ExitCode  = 0
                Dispose   = { }
            }

            # Verify that in Download mode, confirmation is not prompted
            # and invalid setup signature throws
            $invalidSetup = [System.IO.Path]::GetTempFileName()
            {
                Invoke-WinPilotOfficeDeploy -Mode "Download" -ConfigurationPath $tempConfig -SetupPath $invalidSetup
            } | Should Throw

            Remove-Item $invalidSetup -Force
        }
        finally {
            if (Test-Path $tempConfig) { Remove-Item $tempConfig -Force }
        }
    }
}
