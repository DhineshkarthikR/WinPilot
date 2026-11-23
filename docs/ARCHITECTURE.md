# WinPilot Technical Architecture Specification

## 1. System Overview & Core Invariants

WinPilot is a modular Windows and Microsoft Office management and diagnostic toolkit implemented in pure PowerShell. It is engineered to adhere to strict enterprise security standards:

```
+-------------------------------------------------------------------------+
|                               WinPilot                                  |
|                 Independent Windows & Office Toolkit                    |
+-------------------------------------------------------------------------+
                                    |
          +-------------------------+-------------------------+
          |                                                   |
+--------------------+                               +--------------------+
|    Core Runtime    |                               | Modular Subsystems |
| - Host Detection   |                               | - Diagnostics      |
| - ANSI TUI Engine  |                               | - Office Deploy    |
| - Input & Keys     |                               | - Office Maint.    |
| - Audit Logger     |                               | - System Repair*   |
| - Safety Guards    |                               | - Security Engine  |
| - Process Wrapper  |                               +--------------------+
+--------------------+
(* Milestone 5: Proposed)
```

### Core Invariants
1. **Zero Activation Circumvention**: Strictly no activation bypasses, KMS emulation, or license tampering. All diagnostics query supported Microsoft APIs in read-only mode.
2. **First-Party Tooling Only**: Office operations rely exclusively on official Microsoft Office Deployment Tool (ODT) binaries (`setup.exe`).
3. **PowerShell 5.1 & 7+ Dual Compatibility**: Operates natively on clean Windows 10/11 systems without requiring third-party runtime dependencies.
4. **Licensing Privacy**: Complete 25-character product keys are never displayed or logged; OEM keys are masked (`XXXXX-XXXXX-XXXXX-XXXXX-<last5>`).
5. **Safety by Default**: Destructive operations default to `[NO]` and require explicit interactive confirmation (`Confirm-WinPilotAction`).
6. **Process Isolation Wrapper**: External processes are encapsulated via `Invoke-WinPilotProcess`, allowing clean unit testing without launching substitute binaries.

---

## 2. Subsystem Architecture

### A. Core Runtime Subsystem (`src/Core/`)
- **`Host.ps1`**:
  - `Get-WinPilotHost`: Detects Windows OS version, build revision, architecture, PowerShell version/edition, and console host type.
  - `Test-WinPilotAdmin`: Queries `[Security.Principal.WindowsPrincipal]` for elevated administrator privileges.
  - `Initialize-WinPilotConsole`: Sets UTF-8 console output encoding and activates virtual terminal processing (`SetConsoleMode` with `0x0004`).
  - `Invoke-WinPilotProcess`: Encapsulates `System.Diagnostics.Process` with timeout monitoring, error handling, and exit code capture.
- **`AnsiUI.ps1`**:
  - `Get-WinPilotAnsiColor`: Maps standard ANSI/VT100 color codes.
  - `Format-WinPilotBox`: Formats structured text into bordered terminal boxes with automatic width adjustment and text wrapping.
  - `Show-WinPilotHeader`: Standardized top-level status banner showing user privilege, PowerShell edition, and OS build.
  - `Show-WinPilotBanner`: Categorized notifications (`Info`, `Success`, `Warning`, `Error`).
- **`Input.ps1`**:
  - `Read-WinPilotKey`: Captures single keypresses via `[Console]::ReadKey($true)` without echoing characters.
  - `Read-WinPilotChoice`: Validates keypress against allowed keys with loop containment.
  - `Confirm-WinPilotAction`: Interactive prompt defaulting to `[NO]`; high-risk operations require typing explicit `YES`.
- **`Logger.ps1`**:
  - `Initialize-WinPilotLogger`: Creates local log directory at `%ProgramData%\WinPilot\Logs`.
  - `Write-WinPilotLog`: Writes ISO 8601 timestamped structured log lines (`INFO`, `WARN`, `ERROR`, `AUDIT`).

---

### B. Diagnostics Subsystem (`src/Modules/Diagnostics/`)
- **`WindowsLicense.ps1`**:
  - Queries `SoftwareLicensingProduct` via CIM (`Get-CimInstance`) filtering for active Windows licenses.
  - Extracts Product Name, License Channel (Retail, OEM, Volume/MAK, KMS Client), Activation Status (Licensed, Grace, Notification), and Permanent Activation state.
  - Queries `SoftwareLicensingService` for OA3xOriginalProductKey, masking the first 20 characters (`XXXXX-XXXXX-XXXXX-XXXXX-<last5>`).
- **`OfficeLicense.ps1`**:
  - Queries CIM `SoftwareLicensingProduct` for perpetual Office products (Office 2016, 2019, 2021 LTSC).
  - Queries Click-to-Run registry configurations (`HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`).
  - Audits vNext subscription licensing tokens (`SubscriptionTokenCount`), Shared Computer Licensing mode, and token directory status, explicitly separating token presence from active subscription verification.
- **`SystemHealth.ps1`**:
  - Gathers CPU model, physical memory, architecture, and pending reboot registry keys (`RebootPending`, `RebootRequired`, `Component Based Servicing`).
  - Integrates non-destructive DISM component store corruption check (`DISM /Online /Cleanup-Image /CheckHealth`).

---

### C. Office Deployment Subsystem (`src/Modules/OfficeDeploy/`)
- **`OdtEngine.ps1`**:
  - Downloads official Microsoft Office Deployment Tool (`officedeploymenttool.exe`).
  - **Manual Redirect Validation Loop**:
    - Disables auto-redirects (`AllowAutoRedirect = $false`).
    - Uses single-hop request helper `Invoke-WinPilotHttpHop`.
    - Enforces HTTPS on port 443 on every hop.
    - Rejects URLs containing userinfo credentials.
    - Resolves relative and absolute redirect destinations.
    - Supports HTTP 301, 302, 303, 307, and 308 redirects up to a maximum of 5 hops.
    - Restricts hosts strictly to `download.microsoft.com`, `officecdn.microsoft.com`, and `go.microsoft.com`.
  - **Single-Request Streaming**: Directly streams the verified HTTP 200 response to a temporary archive file.
- **`XmlBuilder.ps1`**:
  - Generates valid ODT configuration XML using `System.Xml.XmlWriter` with proper UTF-8 encoding.
  - Supports Microsoft 365 Enterprise (`O365ProPlusRetail`), Business (`O365BusinessRetail`), Office 2021 LTSC Volume (`PerpetualVL2021`), Visio Pro, and Project Pro.
  - Granular application exclusions (`ExcludeApp` for Teams, OneDrive, Outlook, Access, Publisher, etc.).
  - Configurable update channels (Current, MonthlyEnterprise, SemiAnnual), language packs, and Shared Computer Licensing.
- **`DeployRunner.ps1`**:
  - Verifies setup.exe Authenticode signature prior to execution.
  - Executes `Invoke-WinPilotProcess -FilePath $SetupPath -ArgumentList "/configure <config.xml>"`.
  - Maps exit codes to documented Microsoft setup results (0 = Success, 17002 = Installation in progress, 17004 = Cancelled, 30182 = Network error, 30088 = Space/conflict error).

---

### D. Office Maintenance Subsystem (`src/Modules/OfficeMaintenance/`)
- **`OfficeRepair.ps1`**:
  - `Get-WinPilotC2RClient`: Locates native `OfficeClickToRun.exe` registered in Windows Add/Remove Programs (ARP). Enforces strict binary identity:
    - Authenticode signature validity.
    - Publisher equality: `CN=Microsoft Corporation, O=Microsoft Corporation`.
    - Certificate-chain trust to Microsoft Root Authority.
    - Code Signing EKU (`1.3.6.1.5.5.7.3.3`).
    - Exact file identity: `OriginalFilename -ieq "OfficeClickToRun.exe"`.
  - `Invoke-WinPilotOfficeQuickRepair`: Launches supported Windows Installed Apps interface (`ms-settings:installed-apps` / `ms-settings:appsfeatures`) with step-by-step interactive instructions.
  - `Invoke-WinPilotOfficeOnlineRepair`: Executes documented command:
    `OfficeClickToRun.exe scenario=Repair platform=$platform RepairType=FullRepair DisplayLevel=True forceappshutdown=True`
    - Enforces administrator elevation (`Test-WinPilotAdmin`).
    - Dynamically detects Click-to-Run platform (`x86`/`x64`) from the registry and halts if architecture cannot be determined.
    - Displays critical warnings regarding application force-closure and unsaved data loss with explicit typed confirmation.
- **`OfficeUpdate.ps1`**:
  - Discovers Click-to-Run update channel and configuration.
  - Triggers background update check and download using `OfficeC2RClient.exe /update user displaylevel=true`.
  - Distinguishes triggering client launch from confirming full update completion.
- **`OfficeUninstall.ps1`**:
  - Generates removal XML (`<Remove All="TRUE" />`) using `New-WinPilotOfficeRemovalXml`.
  - Discloses all detected products and language packs scheduled for removal.
  - Provides Outlook `.pst`/`.ost` data backup advisories.
  - Guarantees temporary XML cleanup in `try/finally` blocks on success, failure, and interruption.

---

### E. Security & Cryptography Subsystem (`src/Security/`)
- **`Integrity.ps1`**:
  - Computes uppercase 64-character SHA-256 hashes using `System.Security.Cryptography.SHA256`.
  - Validates multi-file release manifests.
- **`SignatureVerifier.ps1`**:
  - Validates digital signatures using `Get-AuthenticodeSignature`.
  - Parses X.500 distinguished name attributes (`CN`, `O`, `OU`, `C`).
  - Validates certificate chain trust using `System.Security.Cryptography.X509Certificates.X509Chain`.
  - Validates Code Signing EKU (`1.3.6.1.5.5.7.3.3`).
- **`SecureBootstrapper.ps1`**:
  - Implements staged local execution pattern: downloads payload to `%TEMP%\WinPilot\Staging\`, validates SHA-256 against signed manifest, verifies Authenticode, executes locally, and cleans up staging directory on exit.

---

## 3. Data Flow Diagrams

### Staged Secure Download & Execution Flow
```
[ Remote Endpoint ] 
        | (HTTPS / Port 443 / Exact Microsoft Allowlist)
        v
[ Invoke-WinPilotHttpHop ] <--- Validates Scheme, Port, UserInfo, Max 5 Redirects (301-308)
        |
        v
[ Stream directly to %TEMP%\WinPilot\ ]
        |
        v
[ Test-WinPilotAuthenticode ] <--- Checks CN/O == Microsoft, Root Chain Trust, Code Signing EKU
        |
        +---> Valid: Proceed to Execution via Invoke-WinPilotProcess
        +---> Invalid: Delete Artifact Immediately & Throw Security Alert
```

### Safety Guardrail Flow
```
[ User Action Selected ]
        |
        v
[ Action Severity Evaluation ]
        |
        +---> Moderate Risk: Confirm-WinPilotAction [y/N] (Default: NO)
        |
        +---> High/Critical Risk: Confirm-WinPilotAction (Requires typed "YES", Default: NO)
        |
        +---> Cancelled: Log AUDIT message, preserve environment state, return Failure object
        +---> Confirmed: Log AUDIT message, proceed with isolated execution
```
