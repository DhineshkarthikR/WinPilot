# WinPilot Quick Start Guide

Get started with WinPilot in under 2 minutes.

---

## 1. Prerequisites

Before using WinPilot, ensure your environment meets these requirements:

- **Operating System**: Windows 10 (Version 1809 or higher), Windows 11 (all versions), or Windows Server 2019/2022.
- **PowerShell**: Built-in Windows PowerShell 5.1 **or** PowerShell Core 7+ (`pwsh`).
- **Privileges**: Standard user permissions for diagnostics; elevated Administrator permissions for deployment, repair, and uninstallation.
- **Network**: Outbound HTTPS (Port 443) connectivity to official Microsoft domains (`*.microsoft.com`).

---

## 2. Installation & First Launch

### Method A: Interactive Terminal Interface (Recommended)

1. Open PowerShell as **Administrator** (recommended for full functionality):
   - Right-click Start > Select **Terminal (Admin)** or **Windows PowerShell (Admin)**.

2. Clone the repository and navigate to the folder:
   ```powershell
   git clone https://github.com/winpilot/winpilot.git
   cd winpilot
   ```

3. Configure execution policy for the current process scope and launch:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
   Import-Module .\src\WinPilot.psd1 -Force
   Start-WinPilot
   ```

4. Use the single-keypress menu to navigate:
   - Press `1` for Licensing & System Diagnostics.
   - Press `2` for Office Deployment Suite.
   - Press `3` for Office Maintenance & Repair.
   - Press `0` or `ESC` to return or exit.

---

### Method B: Headless / Scriptable Automation

You can import WinPilot as a standard PowerShell module in scripts or automated pipelines:

```powershell
Import-Module .\src\WinPilot.psd1
```

Once imported, all 45 exported cmdlets are directly available.

---

## 3. Common Workflow Examples

### A. Audit Windows Activation Status
```powershell
# Display formatted terminal box report
Show-WinPilotWindowsLicenseReport

# Query structured object for scripting
$lic = Get-WinPilotWindowsLicense
Write-Host "Status: $($lic.ActivationStatus) | Channel: $($lic.LicenseChannel) | Key: $($lic.MaskedKey)"
```

### B. Audit Microsoft Office & Microsoft 365
```powershell
# Display combined Office report
Show-WinPilotOfficeLicenseReport

# Query Microsoft 365 subscription status and vNext tokens
$sub = Get-WinPilotOfficeSubscriptionStatus
Write-Host "M365 Installed: $($sub.IsClickToRunInstalled) | Token Count: $($sub.SubscriptionTokenCount)"
```

### C. Deploy Microsoft 365 Apps for Enterprise
```powershell
# 1. Generate deployment configuration excluding Teams and OneDrive
New-WinPilotOfficeXml -ProductId "O365ProPlusRetail" `
                      -Architecture "x64" `
                      -Channel "Current" `
                      -Languages @("en-us") `
                      -ExcludeApps @("Teams", "OneDrive") `
                      -OutputPath "$env:TEMP\office_config.xml"

# 2. Acquire official ODT binary (setup.exe) with Authenticode verification
$setup = Get-WinPilotOdt -TargetDirectory "$env:TEMP\ODT"

# 3. Execute installation (requires elevation and explicit confirmation)
Invoke-WinPilotOfficeDeploy -Mode "Install" -ConfigurationPath "$env:TEMP\office_config.xml"
```

### D. Perform Office Repair
```powershell
# Guided Quick Repair (launches official Windows Settings interface)
Invoke-WinPilotOfficeQuickRepair

# Cloud-Streamed Online Repair (reinstalls components from Microsoft CDN)
# Note: Requires Administrator elevation and closes running Office applications
Invoke-WinPilotOfficeOnlineRepair
```

### E. Check & Trigger Office Updates
```powershell
# Inspect current update channel and status
$cfg = Get-WinPilotOfficeUpdateConfig
Write-Host "Channel: $($cfg.UpdateChannel) | Updates Enabled: $($cfg.UpdatesEnabled)"

# Trigger background update check
Invoke-WinPilotOfficeUpdate
```

### F. Clean Uninstall of Microsoft Office
```powershell
# Generates removal XML, presents impact disclosures, and uninstalls cleanly
Invoke-WinPilotOfficeUninstall
```

---

## 4. Running the Automated Tests

Verify that your environment passes the complete unit test suite (109 tests):

```powershell
$testFiles = Get-ChildItem -Path ".\tests\Unit" -Filter "*.Tests.ps1" | Select-Object -ExpandProperty FullName
Invoke-Pester -Script $testFiles -PassThru
```

---

## 5. Troubleshooting & FAQ

- **Error: "Script execution is disabled on this system"**:
  Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force`. This only affects the current PowerShell session without modifying system-wide security settings.
- **Why is my product key masked?**:
  By design, WinPilot prioritizes user privacy and never displays or logs full 25-character product keys. Only the last 5 characters are displayed to confirm license binding.
- **Where are the logs located?**:
  All operations are logged to `%ProgramData%\WinPilot\Logs\WinPilot_<date>.log`.
