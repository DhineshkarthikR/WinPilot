# WinPilot: Independent Windows & Office Management Toolkit

WinPilot is an open-source, modular Windows and Microsoft Office management and diagnostic toolkit designed for system administrators and power users. Inspired by terminal-driven administration utilities, WinPilot focuses exclusively on legitimate systems administration, official Microsoft Office deployment, diagnostic auditing, and system maintenance.

---

## Key Principles & Guardrails

- **Zero Unauthorized Activation**: No activation bypasses, KMS emulators, or license modification tools. All licensing checks use supported, read-only Microsoft interfaces.
- **First-Party Tooling**: Office deployments rely strictly on Microsoft's official Office Deployment Tool (ODT) with Authenticode signature verification.
- **PowerShell 5.1 & 7+ Dual Compatibility**: Operates natively on clean Windows 10 and Windows 11 systems without external dependencies.
- **Secure Staging Workflow**: Replaces blind `iex` execution with a staged download, SHA-256 integrity check, and local execution process.
- **Safety by Default**: Destructive operations require explicit confirmation (defaulting to NO) and support recovery procedures.
- **Full Audit Logging**: Local timestamped session logs are recorded to `%ProgramData%\WinPilot\Logs`.

---

## Project Structure

```
WinPilot/
├── .github/workflows/          # CI pipeline for PS 5.1 and PS Core
├── build/                      # Bundler and release compilation tools
├── docs/                       # Architecture, security, and module specifications
├── src/
│   ├── WinPilot.psd1           # Module manifest
│   ├── WinPilot.psm1           # Module root loader and interactive orchestrator
│   ├── Core/                   # Host detection, AnsiUI, Input, Logger
│   ├── Modules/                # Diagnostics, Office Deploy, Maintenance, System Repair
│   └── Security/               # Integrity verification, Authenticode validation
├── tests/                      # Pester unit and integration test suites
└── web/                        # Vercel CDN distribution endpoints
```

---

## Status: Milestone 1 Completed

- [x] Repository scaffold & module manifest (`WinPilot.psd1`)
- [x] Core host detection (`Get-WinPilotHost`, `Test-WinPilotAdmin`)
- [x] ANSI/VT100 terminal engine (`AnsiUI.ps1`, `Format-WinPilotBox`, `Show-WinPilotHeader`)
- [x] Keyboard navigation & safety confirmations (`Read-WinPilotChoice`, `Confirm-WinPilotAction`)
- [x] Structured file & console logger (`Initialize-WinPilotLogger`, `Write-WinPilotLog`)
- [x] Pester unit tests (12/12 passing)
- [ ] Milestone 2: Diagnostics Subsystem (Pending approval)
