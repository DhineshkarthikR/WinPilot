# WinPilot Technical Architecture Specification

## 1. Architecture Review & Resolved Technical Inconsistencies

During the architectural review, key inconsistencies were identified and resolved:

1. **Remote Execution Safety**:
   - *Problem*: Direct piping of web downloads into `Invoke-Expression` (`irm ... | iex`) provides zero tamper detection, prevents digital signature validation, and executes partial streams on network interruption.
   - *Resolution*: Replaced with a **staged local execution workflow**. The bootstrapper downloads payload files to a temporary staging folder, verifies the cryptographic SHA-256 hash against a signed manifest, verifies Authenticode signatures, executes the script locally, and purges the staging directory.

2. **PowerShell 5.1 Syntax Containment**:
   - *Problem*: PowerShell 7 language operators (ternary `?:`, null-coalescing `??=`, and pipeline chains `&&` / `||`) fail on Windows PowerShell 5.1 (the default engine on Windows 10 and Windows 11).
   - *Resolution*: Enforced strict PS 5.1 syntax constraints across all modules, verified via dual-shell CI matrix (Windows PowerShell + PowerShell Core).

3. **Office Licensing Architectural Distinction**:
   - *Problem*: Treating Microsoft 365 (subscription-based Click-to-Run vNext) and perpetual Office (Volume/Retail via OSPP/KMS/MAK) under a single query leads to ambiguous and inaccurate licensing reports.
   - *Resolution*: Decoupled into two separate diagnostic functions:
     - `Get-WinPilotOfficePerpetualStatus`: Queries OSPP and `SoftwareLicensingProduct` via CIM/WMI.
     - `Get-WinPilotOfficeSubscriptionStatus`: Queries Click-to-Run configuration, subscription user licensing tokens, and vNext diagnostic registry branches.

4. **Rollback & Recovery for System-Changing Actions**:
   - *Problem*: Running repairs (DISM restore, Windows Update cache reset) without a fallback can disrupt working configurations.
   - *Resolution*: Implemented pre-action safeguards:
     - System Restore Point verification (`Checkpoint-Computer`) before major system alterations.
     - Backup of existing services and software distribution directories prior to Windows Update reset.
     - Non-destructive default choices (`[NO]`) for all confirmation prompts.

---

## 2. Component Design

```
+-------------------------------------------------------------------------+
|                              WinPilot                                    |
+-------------------------------------------------------------------------+
                                    |
           +------------------------+------------------------+
           |                                                 |
+--------------------+                             +--------------------+
|  Core Runtime      |                             | Modular Subsystems |
| - Host Detection   |                             | - Diagnostics      |
| - ANSI TUI Engine  |                             | - Office Deploy    |
| - Input & Keys     |                             | - Office Maint.    |
| - Audit Logger     |                             | - System Repair    |
| - Safety Guards    |                             | - Security Engine  |
+--------------------+                             +--------------------+
```

### Staged Secure Web Bootstrapper Flow
```
1. Fetch release manifest (JSON with version + SHA-256) via TLS 1.2+
2. Download payload into %TEMP%\WinPilot\Staging\
3. Compute SHA-256 hash of downloaded file
4. If hash != manifest.hash -> ABORT with Security Alert
5. If signed binary -> Verify Get-AuthenticodeSignature Status == Valid
6. Execute local script with -Scope Process
7. Clean up staging directory on exit
```

---

## 3. Milestone Roadmap

- **Milestone 1 (Complete)**: Scaffolding, Core Host Detection, ANSI TUI, Keyboard Navigation, Logging, Pester Unit Tests.
- **Milestone 2 (Next)**: Diagnostics Subsystem (Windows Licensing, Perpetual Office, M365 Subscription, Component Store Health).
- **Milestone 3**: Office Deployment Suite (ODT Engine, Authenticode Validation, Dynamic XML Generator, Runner).
- **Milestone 4**: Office Maintenance & Repair (Quick/Online Repair, Update Forcing, Clean Uninstaller).
- **Milestone 5**: System Troubleshooting & Repair (SFC/DISM Wrappers, WU Reset with Backup, Network Stack).
- **Milestone 6**: Build Pipeline, Single-File Bundler & Vercel Edge Distribution.
- **Milestone 7**: Integration Validation, Windows Sandbox Testing Matrix, Documentation.
