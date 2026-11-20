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

    It "Strictly masks OEM product key and never returns complete 25-character key" {
        $lic = Get-WinPilotWindowsLicense
        if ($lic.OemKeyEmbedded -ne "None Detected") {
            $lic.OemKeyEmbedded | Should Match "^XXXXX-XXXXX-XXXXX-XXXXX-[A-Z0-9]{5}$"
        }
    }

    It "Partial product key contains at most 5 characters" {
        $lic = Get-WinPilotWindowsLicense
        if ($lic.PartialProductKey -ne "None") {
            $lic.PartialProductKey.Length | Should BeLessThan 6
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

    It "Distinguishes cached token files from verified subscription status" {
        $sub = Get-WinPilotOfficeSubscriptionStatus
        # Token status must not claim verified active subscription on its own
        $sub.TokenStatus | Should Match "Verification required|No Cached Tokens"
        $sub.VerifiedSubscriptionStatus | Should Not BeNullOrEmpty
    }
}

Describe "WinPilot Diagnostics Negative & Failure Scenarios" {
    It "Handles simulated inaccessible CIM or empty license collection gracefully" {
        Mock -ModuleName WinPilot Get-CimInstance {
            throw [System.Management.Automation.ItemNotFoundException]"Simulated CIM Access Denied"
        }

        # Must not throw unhandled exception; return graceful fallback object
        $lic = Get-WinPilotWindowsLicense
        $lic.LicenseStatus | Should Be -1
        $lic.LicenseStatusText | Should Be "Unknown"

        $perps = Get-WinPilotOfficePerpetualStatus
        $perps.Count | Should Be 0
    }

    It "Classifies unrecognized perpetual licensing channels as Unspecified / Ambiguous" {
        Mock -ModuleName WinPilot Get-CimInstance {
            return @(
                [PSCustomObject]@{
                    Name = "Office Custom Test"
                    Description = "Office 16, UNKNOWN_CHANNEL_STRING edition"
                    LicenseStatus = 1
                    PartialProductKey = "99999"
                    GracePeriodRemaining = 0
                }
            )
        }

        $perps = Get-WinPilotOfficePerpetualStatus
        $perps.Count | Should Be 1
        $perps[0].LicensingChannel | Should Be "Unspecified / Ambiguous Channel"
    }

    It "Handles missing ClickToRun registry gracefully" {
        Mock -ModuleName WinPilot Test-Path { return $false }

        $sub = Get-WinPilotOfficeSubscriptionStatus
        $sub.IsClickToRunInstalled | Should Be $false
        $sub.InstallationState | Should Be "Not Installed"
        $sub.Version | Should Be "Not Installed"
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
