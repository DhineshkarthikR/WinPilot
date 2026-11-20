#
# Pester Unit Tests for WinPilot Milestone 2 - Diagnostics & Licensing Subsystem
# Compatible with PowerShell 5.1 and modern PowerShell
#

$modulePath = Resolve-Path "$PSScriptRoot\..\..\src\WinPilot.psd1"
Import-Module $modulePath -Force

Describe "WinPilot Windows Licensing Diagnostics" {
    It "Get-WinPilotWindowsLicense returns expected schema properties" {
        $lic = Get-WinPilotWindowsLicense
        $lic | Should Not BeNullOrEmpty
        $lic.ProductName | Should Not BeNullOrEmpty
        $lic.LicenseStatus | Should Not BeNullOrEmpty
        $lic.LicenseStatusText | Should Not BeNullOrEmpty
        $lic.LicensingChannel | Should Not BeNullOrEmpty
        $lic.PartialProductKey | Should Not BeNullOrEmpty
        $lic.OemKeyEmbedded | Should Not BeNullOrEmpty
    }

    It "Masks OEM product key by default for privacy" {
        $lic = Get-WinPilotWindowsLicense
        if ($lic.OemKeyEmbedded -ne "None Detected") {
            $lic.OemKeyEmbedded | Should Match "XXXXX"
        }
    }

    It "Unmasks OEM key when -ShowFullKey switch is provided" {
        $lic = Get-WinPilotWindowsLicense -ShowFullKey
        if ($lic.OemKeyEmbedded -ne "None Detected") {
            $lic.OemKeyEmbedded.Length | Should BeGreaterThan 10
        }
    }

    It "Evaluates IsPermanentlyActivated as a boolean" {
        $lic = Get-WinPilotWindowsLicense
        ($lic.IsPermanentlyActivated -eq $true -or $lic.IsPermanentlyActivated -eq $false) | Should Be $true
    }

    It "Show-WinPilotWindowsLicenseReport renders without throwing" {
        { Show-WinPilotWindowsLicenseReport } | Should Not Throw
    }
}

Describe "WinPilot Perpetual Office Licensing Diagnostics" {
    It "Get-WinPilotOfficePerpetualStatus returns an array and does not throw" {
        $perps = Get-WinPilotOfficePerpetualStatus
        ($perps -is [System.Array]) | Should Be $true
    }

    It "Excludes pure time-based subscription licenses from perpetual results" {
        $perps = Get-WinPilotOfficePerpetualStatus
        foreach ($p in $perps) {
            $p.Description | Should Not Match "TIMEBASED_SUB"
            $p.ProductName | Should Not Match "O365|Subscription"
        }
    }

    It "Validates perpetual license schema if licenses are present" {
        $perps = Get-WinPilotOfficePerpetualStatus
        if ($perps.Count -gt 0) {
            $first = $perps[0]
            $first.ProductName | Should Not BeNullOrEmpty
            $first.LicenseStatusText | Should Not BeNullOrEmpty
            $first.LicensingChannel | Should Not BeNullOrEmpty
            $first.PartialProductKey | Should Not BeNullOrEmpty
        }
    }
}

Describe "WinPilot Microsoft 365 Subscription Diagnostics" {
    It "Get-WinPilotOfficeSubscriptionStatus returns valid subscription schema" {
        $sub = Get-WinPilotOfficeSubscriptionStatus
        $sub | Should Not BeNullOrEmpty
        ($sub.IsClickToRunInstalled -eq $true -or $sub.IsClickToRunInstalled -eq $false) | Should Be $true
        $sub.ProductReleaseIds | Should Not BeNullOrEmpty
        $sub.Version | Should Not BeNullOrEmpty
        $sub.UpdateChannel | Should Not BeNullOrEmpty
        ($sub.SharedComputerLicensing -eq $true -or $sub.SharedComputerLicensing -eq $false) | Should Be $true
        ($sub.SubscriptionTokenCount -ge 0) | Should Be $true
    }

    It "Translates known Office CDN update channel URLs to friendly names" {
        $sub = Get-WinPilotOfficeSubscriptionStatus
        if ($sub.IsClickToRunInstalled -and -not [string]::IsNullOrEmpty($sub.UpdateChannelUrl)) {
            $sub.UpdateChannel | Should Not BeNullOrEmpty
        }
    }

    It "Show-WinPilotOfficeLicenseReport renders both reports without throwing" {
        { Show-WinPilotOfficeLicenseReport } | Should Not Throw
    }
}

Describe "WinPilot System Specifications & Health Diagnostics" {
    It "Get-WinPilotSystemHealth returns valid hardware and OS metrics" {
        $health = Get-WinPilotSystemHealth
        $health | Should Not BeNullOrEmpty
        $health.OSCaption | Should Not BeNullOrEmpty
        $health.BuildNumber | Should BeGreaterThan 0
        $health.CPUName | Should Not BeNullOrEmpty
        $health.CPUCores | Should BeGreaterThan 0
        $health.TotalRamGB | Should BeGreaterThan 0
        $health.Uptime | Should Not BeNullOrEmpty
        $health.FirmwareType | Should Not BeNullOrEmpty
    }

    It "Evaluates pending reboot state as a boolean" {
        $health = Get-WinPilotSystemHealth
        ($health.IsRebootPending -eq $true -or $health.IsRebootPending -eq $false) | Should Be $true
    }

    It "Test-WinPilotComponentStore handles non-elevated execution gracefully" {
        # When running without admin elevation, it reports ElevationRequired without crashing
        $dism = Test-WinPilotComponentStore
        $dism | Should Not BeNullOrEmpty
        $dism.Status | Should Not BeNullOrEmpty
        if (-not (Test-WinPilotAdmin)) {
            $dism.Status | Should Be "ElevationRequired"
            $dism.SummaryMessage | Should Match "Administrator rights"
        }
    }

    It "Show-WinPilotSystemHealthReport renders without throwing" {
        { Show-WinPilotSystemHealthReport } | Should Not Throw
    }
}
