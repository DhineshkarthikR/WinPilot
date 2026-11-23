# Changelog

All notable changes to the WinPilot project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned (Milestone 5 — Awaiting Authorization)
- Windows Component Store repair wrapper (`DISM /Online /Cleanup-Image /RestoreHealth`).
- System File Checker integration (`SFC /scannow`) with CBS log parsing.
- Automated Windows Update service and cache reset with pre-flight registry and file backups.
- Network stack reset automation (TCP/IP stack, Winsock catalog, DNS flush).

---

## [0.4.0] - 2026-11-21

### Milestone 4 — Office Maintenance & Lifecycle Management
#### Added
- **Guided Quick Repair**: Added `Invoke-WinPilotOfficeQuickRepair` launching the supported Windows Installed Apps interface (`ms-settings:installed-apps` / `ms-settings:appsfeatures`) with step-by-step interactive instructions.
- **Cloud-Streamed Online Repair**: Added `Invoke-WinPilotOfficeOnlineRepair` invoking `OfficeClickToRun.exe scenario=Repair platform=$platform RepairType=FullRepair DisplayLevel=True forceappshutdown=True`.
- **Architecture Discovery**: Online Repair dynamically discovers target architecture (`x86`/`x64`) from the Click-to-Run registry and halts cleanly if architecture cannot be determined.
- **Safety Warnings**: Mandatory red critical warnings and high-risk confirmation before executing Online Repair with `forceappshutdown=True`.
- **Elevation Enforcement**: Online Repair requires elevated administrator privileges (`Test-WinPilotAdmin`).
- **Strict Click-to-Run Binary Identity**: Updated `Get-WinPilotC2RClient` to enforce `OriginalFilename -ieq "OfficeClickToRun.exe"` alongside Authenticode, Microsoft publisher subject, and Code Signing EKU checks.
- **Office Update Management**: Added `Get-WinPilotOfficeUpdateConfig` and `Invoke-WinPilotOfficeUpdate` using `OfficeC2RClient.exe /update user displaylevel=true`.
- **Clean Office Uninstallation**: Added `Invoke-WinPilotOfficeUninstall` using ODT removal configuration (`<Remove All="TRUE" />`) with full product and language impact disclosure and Outlook data preservation advisories.
- **Process Isolation Wrapper**: Added `Invoke-WinPilotProcess` in `Host.ps1` for robust timeout handling and decoupled unit test mocking without spawning substitute binaries.

---

### Milestone 3 — Legitimate Microsoft Office Deployment
#### Added
- **ODT Acquisition Engine**: Added `Get-WinPilotOdt` for downloading official Microsoft Office Deployment Tool (`setup.exe`).
- **Redirect Hardening**: Implemented manual redirect loop (`AllowAutoRedirect = $false`) with single-hop request helper `Invoke-WinPilotHttpHop`, enforcing HTTPS on port 443, rejecting userinfo credentials, supporting HTTP 308 redirects, and limiting redirects to 5 hops.
- **Host Allowlist**: Strict hostname enforcement restricted to `download.microsoft.com`, `officecdn.microsoft.com`, and `go.microsoft.com`.
- **Single-Request Direct Streaming**: Streamed directly from verified HTTP 200 response streams to temporary archives without duplicate connections.
- **Authenticode Validation**: Added `Test-WinPilotAuthenticode` validating `CN=Microsoft Corporation, O=Microsoft Corporation`, root chain trust, and Code Signing EKU (`1.3.6.1.5.5.7.3.3`).
- **Declarative XML Builder**: Added `New-WinPilotOfficeXml` supporting Microsoft 365 Apps (Enterprise/Business), Office 2021 LTSC Volume (`PerpetualVL2021`), Visio Pro, Project Pro, language packs, granular app exclusions, and Shared Computer Licensing.
- **Deployment Runner**: Added `Invoke-WinPilotOfficeDeploy` with documented exit-code mapping and confirmation safety guardrails.

---

### Milestone 2 — Licensing & System Diagnostics
#### Added
- **Windows License Audit**: Added `Get-WinPilotWindowsLicense` and `Show-WinPilotWindowsLicenseReport` querying CIM/WMI `SoftwareLicensingProduct` for activation status, channel, evaluation grace period, and permanent activation state.
- **Licensing Privacy**: Strict OEM BIOS/UEFI embedded key masking (`XXXXX-XXXXX-XXXXX-XXXXX-<last5>`), completely prohibiting display or logging of full 25-character keys.
- **Perpetual Office Diagnostics**: Added `Get-WinPilotOfficePerpetualStatus` discovering Office 2016/2019/2021 LTSC licenses via OSPP and CIM providers without altering licensing records.
- **Microsoft 365 Subscription Separation**: Added `Get-WinPilotOfficeSubscriptionStatus` querying Click-to-Run vNext subscription tokens and Shared Computer Licensing, explicitly separating token presence from active subscription verification.
- **Component Store Health**: Added `Get-WinPilotSystemHealth` and `Test-WinPilotComponentStore` checking DISM health states and pending reboot flags.

---

### Milestone 1 — Core Runtime & Interface Architecture
#### Added
- **Repository Scaffold & Manifest**: Initialized `WinPilot.psd1` and `WinPilot.psm1` module scaffold.
- **Host Environment Detection**: Added `Get-WinPilotHost` and `Test-WinPilotAdmin` for runtime version inspection (PS 5.1/7+) and privilege auditing.
- **Terminal UI Engine**: Added `AnsiUI.ps1`, `Format-WinPilotBox`, `Show-WinPilotHeader`, and `Show-WinPilotBanner` supporting zero-dependency VT100/ANSI rendering.
- **Interactive Keyboard Input**: Added `Read-WinPilotKey`, `Read-WinPilotChoice`, and `Confirm-WinPilotAction` with non-destructive defaults (`[NO]`).
- **Structured Audit Logger**: Added `Initialize-WinPilotLogger`, `Get-WinPilotLogPath`, and `Write-WinPilotLog` recording local audit logs to `%ProgramData%\WinPilot\Logs`.
- **Test Framework**: Initialized Pester test suite with strict dual-compatibility syntax.
