# WinPilot Milestone History & Roadmap

This document outlines the detailed architectural milestone history of WinPilot, tracking completed milestones (Milestones 1–4) and the proposed roadmap for future development (Milestones 5–7).

---

## Completed Milestones

### Milestone 1 — Core Host, Terminal UI & Logging Foundation
*Status: Completed & Validated (Commit `7e1a3bc`)*

- [x] **Scaffolding & Manifest**: PowerShell module manifest (`src/WinPilot.psd1`) and root loader (`src/WinPilot.psm1`).
- [x] **Host Environment Detection** (`src/Core/Host.ps1`):
  - `Get-WinPilotHost`: Runtime environment detection (PowerShell 5.1/7+, Windows 10/11 build numbers, terminal host detection).
  - `Test-WinPilotAdmin`: Privilege detection via WindowsPrincipal.
  - `Initialize-WinPilotConsole`: Safe UTF-8 console output encoding and virtual terminal processing (`ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004`).
- [x] **ANSI/VT100 Terminal Engine** (`src/Core/AnsiUI.ps1`):
  - `Get-WinPilotAnsiColor`: ANSI escape sequence mapping.
  - `Format-WinPilotBox`: Dynamic box-drawing with responsive text wrapping and title styling.
  - `Show-WinPilotHeader`: Standardized status header banner.
  - `Show-WinPilotBanner`: Categorized notifications (`Info`, `Success`, `Warning`, `Error`).
- [x] **Keyboard Navigation & Safety** (`src/Core/Input.ps1`):
  - `Read-WinPilotKey` & `Read-WinPilotChoice`: Single-keypress input processing (`1`–`9`, `0`/`ESC` to exit).
  - `Confirm-WinPilotAction`: Interactive confirmation defaulting to `[NO]`; high-risk confirmation requiring explicit typed `YES`.
- [x] **Structured Audit Logger** (`src/Core/Logger.ps1`):
  - `Initialize-WinPilotLogger`: Dedicated log folder initialization (`%ProgramData%\WinPilot\Logs`).
  - `Write-WinPilotLog`: Timestamped structured logging (`INFO`, `WARN`, `ERROR`, `AUDIT`).
- [x] **Pester Test Foundation**: 12 passing unit tests in `tests/Unit/Core.Tests.ps1`.

---

### Milestone 2 — Licensing & System Diagnostics Subsystem
*Status: Completed & Validated (Commit `8fa21cd`)*

- [x] **Windows Licensing Audit** (`src/Modules/Diagnostics/WindowsLicense.ps1`):
  - `Get-WinPilotWindowsLicense`: Queries CIM/WMI `SoftwareLicensingProduct` for product name, channel (Retail, OEM, Volume/MAK, KMS Client), activation state, evaluation grace period, and permanent activation flag.
  - `Show-WinPilotWindowsLicenseReport`: Formatted terminal box report.
- [x] **Licensing Privacy Guardrails**:
  - Removed all parameters capable of returning complete product keys.
  - OEM embedded BIOS/UEFI keys are masked (`XXXXX-XXXXX-XXXXX-XXXXX-<last5>`).
  - Complete 25-character keys are never displayed or stored in logs.
- [x] **Perpetual Office Licensing** (`src/Modules/Diagnostics/OfficeLicense.ps1`):
  - `Get-WinPilotOfficePerpetualStatus`: Queries OSPP and CIM providers for perpetual Office 2016/2019/2021 LTSC licenses without altering licensing records.
- [x] **Microsoft 365 Subscription Separation**:
  - `Get-WinPilotOfficeSubscriptionStatus`: Discovers Click-to-Run vNext subscription tokens and Shared Computer Licensing.
  - Explicitly separates cached token presence from verified active subscription state.
  - `Show-WinPilotOfficeLicenseReport`: Unified terminal report for perpetual and subscription Office licenses.
- [x] **Component Store & Health** (`src/Modules/Diagnostics/SystemHealth.ps1`):
  - `Get-WinPilotSystemHealth`: System specifications, RAM, CPU, OS build, and pending reboot detection.
  - `Test-WinPilotComponentStore`: Non-destructive DISM component store corruption auditing (`CheckHealth`).
- [x] **Pester Unit Tests**: 38 passing unit tests (Core + Diagnostics).

---

### Milestone 3 — Legitimate Microsoft Office Deployment Engine
*Status: Completed & Validated (Commit `52c1591`)*

- [x] **Hardened ODT Downloader** (`src/Modules/OfficeDeploy/OdtEngine.ps1`):
  - `Get-WinPilotOdt`: Automated acquisition of official Microsoft Office Deployment Tool (`officedeploymenttool.exe`).
  - Manual redirect loop (`AllowAutoRedirect = $false`) enforcing HTTPS on port 443, rejecting userinfo credentials, and enforcing approved Microsoft hostnames (`download.microsoft.com`, `officecdn.microsoft.com`, `go.microsoft.com`).
  - Single-request direct streaming from verified HTTP 200 responses to local archive files.
- [x] **Authenticode Signature Verification** (`src/Security/SignatureVerifier.ps1`):
  - `Test-WinPilotAuthenticode`: Validates Authenticode signature, exact publisher subject (`CN=Microsoft Corporation, O=Microsoft Corporation`), certificate-chain trust to Microsoft Root Authority, and Code Signing EKU (`1.3.6.1.5.5.7.3.3`).
- [x] **Declarative XML Generator** (`src/Modules/OfficeDeploy/XmlBuilder.ps1`):
  - `New-WinPilotOfficeXml`: Dynamic generation of validated ODT configuration XML.
  - Supports Microsoft 365 Enterprise (`O365ProPlusRetail`), Business (`O365BusinessRetail`), Office 2021 LTSC Volume (`PerpetualVL2021`), Visio Pro, and Project Pro.
  - Granular application exclusions (Teams, OneDrive, Outlook, Access, Publisher, etc.).
  - Shared Computer Licensing, custom update channels, language packs, and 32/64-bit architecture selection.
- [x] **Deployment Runner** (`src/Modules/OfficeDeploy/DeployRunner.ps1`):
  - `Invoke-WinPilotOfficeDeploy`: Executes ODT setup in Download or Install mode with confirmation guardrails and documented exit-code mapping.
- [x] **Pester Unit Tests**: 68 passing unit tests (Core + Diagnostics + OfficeDeploy).

---

### Milestone 4 — Office Maintenance & Lifecycle Management
*Status: Completed & Validated (Commits `b00287b`, `3425072`, `0dea2de`)*

- [x] **Guided Quick Repair** (`src/Modules/OfficeMaintenance/OfficeRepair.ps1`):
  - `Invoke-WinPilotOfficeQuickRepair`: Launches supported Windows Installed Apps interface (`ms-settings:installed-apps` / `ms-settings:appsfeatures`) with step-by-step interactive instructions.
  - Reports `Launched = $true, Completed = "External"` without claiming premature CLI completion.
- [x] **Cloud-Streamed Online Repair**:
  - `Invoke-WinPilotOfficeOnlineRepair`: Invokes documented command:
    `OfficeClickToRun.exe scenario=Repair platform=$platform RepairType=FullRepair DisplayLevel=True forceappshutdown=True`
  - Dynamic Click-to-Run registry architecture detection (`x86`/`x64`) with strict halting if architecture is unknown.
  - Mandatory administrator privilege check (`Test-WinPilotAdmin`).
  - Critical red warnings regarding application termination and unsaved data loss with explicit typed confirmation.
- [x] **Strict Click-to-Run Binary Identity**:
  - `Get-WinPilotC2RClient`: Requires `OriginalFilename -ieq "OfficeClickToRun.exe"` alongside Authenticode, publisher identity, root chain trust, and Code Signing EKU.
- [x] **Office Update Management** (`src/Modules/OfficeMaintenance/OfficeUpdate.ps1`):
  - `Get-WinPilotOfficeUpdateConfig` & `Invoke-WinPilotOfficeUpdate`: Discovers update channel and triggers background update inspections using `OfficeC2RClient.exe /update user displaylevel=true`.
- [x] **Clean Office Uninstallation** (`src/Modules/OfficeMaintenance/OfficeUninstall.ps1`):
  - `Invoke-WinPilotOfficeUninstall`: Generates compliant ODT removal configurations (`<Remove All="TRUE" />`).
  - Detailed impact disclosure of all detected products and languages scheduled for removal.
  - Outlook data preservation advisories and guaranteed temporary XML cleanup in `try/finally`.
- [x] **Process Isolation Wrapper** (`src/Core/Host.ps1`):
  - `Invoke-WinPilotProcess`: Dedicated wrapper encapsulating process execution and exit code extraction.
  - Unit tests mock this wrapper without launching real substitute binaries (`powershell.exe`, `notepad.exe`).
- [x] **Pester Unit Tests**: 109 passing unit tests across 5 test suites with 0 failures and 0 PSScriptAnalyzer violations.

---

## Proposed Roadmap

### Milestone 5 — Windows System Troubleshooting & Repair
*Status: Proposed — Awaiting Owner Authorization (NOT STARTED)*

- [ ] **Component Store Repair Wrapper**:
  - Non-destructive image repair via `DISM /Online /Cleanup-Image /RestoreHealth`.
  - CBS log parsing for repair status verification.
- [ ] **System File Checker (SFC)**:
  - Automated `SFC /scannow` execution with real-time progress indicators and CBS log extraction.
- [ ] **Windows Update Service & Cache Reset**:
  - Pre-flight automated backup of existing update registry configurations and SoftwareDistribution folder.
  - Safe stopping and restarting of BITS, CryptSvc, and WUAUSERV services.
  - Rollback capability if service restoration encounters errors.
- [ ] **Network Stack Reset Automation**:
  - Scripted TCP/IP stack reset (`netsh int ip reset`).
  - Winsock catalog reset (`netsh winsock reset`).
  - DNS cache flushing (`Clear-DnsClientCache`) and ARP table refresh.
  - Explicit confirmation requiring system restart.

---

### Milestone 6 — Distribution, Packaging & Edge Delivery
*Status: Planned (Future)*

- [ ] **Single-File Bundler**:
  - Build script in `build/` compiling modular subsystem scripts into a self-contained, signed distribution script (`WinPilot.ps1`).
- [ ] **Release Manifest Signing**:
  - Cryptographic release manifests containing SHA-256 hashes of all bundled assets.
- [ ] **Edge Distribution**:
  - Vercel serverless distribution endpoints (`web/`) serving signed manifests and staged payloads over TLS 1.3.

---

### Milestone 7 — Production Verification & Windows Sandbox Matrix
*Status: Planned (Future)*

- [ ] **Windows Sandbox Testing Matrix**:
  - Automated testing harness executing WinPilot inside clean Windows 10 and Windows 11 Windows Sandbox (WSB) containers.
- [ ] **End-to-End Deployment Verification**:
  - Live testing of Microsoft 365 Apps deployment and clean uninstallation in disposable VMs.
