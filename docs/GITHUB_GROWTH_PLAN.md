# WinPilot 90-Day Organic GitHub Growth & Community Strategy

**Project**: WinPilot  
**Version**: v0.4.0  
**Target Audience**: Systems Administrators, DevOps Engineers, Enterprise IT Staff, PowerShell Developers, and Power Users.

---

## 1. Executive Summary & Ethical Principles

This growth plan establishes a roadmap for growing WinPilot into a reputable, discoverable, and community-driven open-source project.

### Core Ethical Commitments
- **Zero Purchased Engagement**: No purchased stars, forks, or watchers.
- **Zero Bot Automation**: No artificial account activity or synthetic engagement metrics.
- **Zero Forum Spamming**: No unsolicited spamming across Reddit, Discord, or GitHub Discussions.
- **Value-First Discoverability**: Growth is earned strictly through software quality, technical documentation, architectural transparency, and developer utility.

---

## 2. Key Performance Indicators (KPIs) & Tracking

Track the following organic metrics monthly via GitHub Insights:

| Metric | Primary Purpose | Baseline (Month 1) | Target (Day 90) |
| :--- | :--- | :---: | :---: |
| **Unique Visitors** | Discoverability & search reach | Track | 1,000+ / mo |
| **Unique Git Clones** | Developer adoption & local testing | Track | 250+ / mo |
| **GitHub Stars** | Developer bookmarking & interest | Organic | 100+ |
| **Forks** | Developer experimentation & contributions | Organic | 25+ |
| **Watchers** | Active release followers | Organic | 15+ |
| **Contributors** | Community participation & PRs | Core team | 3–5 external |
| **Closed Issues** | Responsiveness & issue triage | 100% triaged | < 7-day turnaround |

---

## 3. 90-Day Phase-by-Phase Roadmap

### Phase 1: Foundation, Presentation & Onboarding (Days 1–30)
- **Goal**: Make the repository compelling and friction-free within 30 seconds of landing.
- **Actions**:
  1. Set repository description and GitHub topics.
  2. Upload social preview image (`docs/assets/social-preview.png`).
  3. Deploy issue templates (`.github/ISSUE_TEMPLATE/`) and pull request template.
  4. Curate and publish 3 beginner-friendly "good first issue" tickets.
  5. Enable GitHub Discussions and seed introductory Q&A topics.
  6. Verify CI badge visibility and 100% passing test state.

### Phase 2: Technical Thought Leadership & Developer Articles (Days 31–60)
- **Goal**: Demonstrate deep engineering credibility through educational articles.
- **Actions**:
  1. Publish Article 1 (*Hardened PowerShell Web Downloads*) on dev.to and Medium.
  2. Publish Article 2 (*Auditing Windows & Office Licensing via CIM/WMI*) targeting enterprise sysadmins.
  3. Publish Article 3 (*Building Interactive Terminal UIs in PowerShell*) demonstrating VT100 techniques.
  4. Share articles to r/PowerShell and r/sysadmin with links to source code explanations.
  5. Triage all incoming issues and pull requests within 48 hours.

### Phase 3: Community Expansion & Release Iteration (Days 61–90)
- **Goal**: Expand real-world adoption and welcome external contributors.
- **Actions**:
  1. Publish formal v0.4.0 showcase on LinkedIn and developer communities.
  2. Request community feedback on proposed Milestone 5 (System Troubleshooting & Repair).
  3. Onboard first external code/docs contributors.
  4. Perform first quarterly analytics and traffic audit.

---

## 4. Developer-Facing Technical Content Strategy

Publish in-depth technical articles demonstrating real engineering decisions from the WinPilot repository:

### Article 1: Hardened PowerShell Web Downloads: Certificate Validation & Redirect Defense
* **Topic**: Why blind `Invoke-Expression (Invoke-WebRequest ...)` is dangerous, and how WinPilot implements secure staged execution.
* **Key Insights**: Disabling `AllowAutoRedirect`, manual hop validation, port 443 enforcement, userinfo rejection, approved host allowlists, and Authenticode certificate chain trust (`X509Chain`).
* **Source Link**: `src/Modules/OfficeDeploy/OdtEngine.ps1` and `src/Security/SignatureVerifier.ps1`.

### Article 2: Auditing Windows & Office Licensing Using Supported CIM/WMI Interfaces
* **Topic**: Diagnosing activation health without third-party activation scripts or registry hacks.
* **Key Insights**: Querying `SoftwareLicensingProduct`, differentiating retail/OEM/volume channels, detecting permanent activation, and protecting privacy by masking OEM embedded BIOS keys.
* **Source Link**: `src/Modules/Diagnostics/WindowsLicense.ps1` and `src/Modules/Diagnostics/OfficeLicense.ps1`.

### Article 3: Building an Interactive ANSI Terminal User Interface in Pure PowerShell
* **Topic**: Creating clean, zero-dependency TUI menus compatible with both Windows Terminal and legacy conhost.exe.
* **Key Insights**: Virtual terminal processing activation (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`), single-keypress input handling (`[Console]::ReadKey($true)`), dynamic box-drawing algorithms, and non-destructive confirmation guardrails.
* **Source Link**: `src/Core/AnsiUI.ps1` and `src/Core/Input.ps1`.

### Article 4: Automating Enterprise Microsoft Office Deployments with Dynamic ODT XML Generation
* **Topic**: Programmatic configuration and deployment of Click-to-Run Office suites using official Microsoft tools.
* **Key Insights**: Programmatic XML construction via `System.Xml.XmlWriter`, handling granular app exclusions, configuring Shared Computer Licensing for VDI, and interpreting documented setup.exe exit codes.
* **Source Link**: `src/Modules/OfficeDeploy/XmlBuilder.ps1` and `src/Modules/OfficeDeploy/DeployRunner.ps1`.

### Article 5: Safe Systems Automation: Process Isolation Wrappers and Explicit Destructive Confirmations
* **Topic**: Protecting user environments from accidental data loss during system maintenance.
* **Key Insights**: Encapsulating `System.Diagnostics.Process` in `Invoke-WinPilotProcess`, designing confirmation prompts that default to `[NO]`, and mocking execution boundaries cleanly in Pester without launching real substitute binaries.
* **Source Link**: `src/Core/Host.ps1` and `src/Modules/OfficeMaintenance/OfficeRepair.ps1`.

### Article 6: Unit Testing Pure PowerShell Architecture Across Dual Runtime Engines
* **Topic**: Writing resilient Pester tests that pass identically on Windows PowerShell 5.1 and PowerShell 7.
* **Key Insights**: Pester 3/4 vs Pester 5 scoping nuances, module-scoped mocking, avoiding PS 7 language syntax in shared codebases, and enforcing static analysis via PSScriptAnalyzer in CI.
* **Source Link**: `.github/workflows/ci.yml` and `tests/Unit/Core.Tests.ps1`.

---

## 5. Launch Announcements

### LinkedIn Launch Announcement (Enterprise & IT Professional)
```text
I am excited to announce the open-source release of WinPilot (v0.4.0) - an independent, security-first Windows and Microsoft Office management toolkit built entirely in PowerShell.

Unlike traditional administration utilities, WinPilot focuses strictly on legitimate systems administration, supported Microsoft interfaces, and defensive engineering:

Key Highlights:
- Supported Licensing Audits: Read-only diagnostics for Windows activation, perpetual Office (LTSC/Retail/Volume), and Microsoft 365 subscriptions via CIM/WMI.
- Privacy by Design: Product keys are masked; full 25-character keys are never displayed or logged.
- Official Office Deployments: Automated acquisition of Microsoft ODT (setup.exe) with strict Authenticode signature validation, redirect hardening, and declarative XML building.
- Office Lifecycle Maintenance: Guided Quick Repair, cloud-streamed Online Repair, and clean uninstallation with data preservation advisories.
- Pure Dual-Engine PowerShell: Native support for Windows PowerShell 5.1 and PowerShell 7+ with 109 passing automated Pester unit tests.
- Zero Unauthorized Activation: Absolutely no KMS emulation, license modification, or bypass mechanisms.

Check out the project on GitHub: https://github.com/winpilot/winpilot

Feedback, contributions, and community discussions are warmly welcome!

#PowerShell #SysAdmin #Windows #DevOps #OpenSource #Office365 #ITInfrastructure
```

---

### Reddit Launch Announcement (r/PowerShell & r/sysadmin)
```text
[Release] WinPilot v0.4.0 - Independent, security-focused Windows & Office management toolkit in pure PowerShell

Hi everyone,

I've been working on WinPilot, an independent PowerShell toolkit designed to streamline Windows diagnostics, official Microsoft Office deployment, and Click-to-Run lifecycle management.

A core frustration with existing tools in this space is that many rely on unauthorized activation hacks, blind `irm | iex` execution, or brittle registry modifications. WinPilot was built with the exact opposite philosophy: legitimate enterprise administration, official Microsoft interfaces, and defensive software security.

Key features in v0.4.0:
1. Licensing & Activation Audits: Queries CIM/WMI `SoftwareLicensingProduct` for Windows activation status, channel, and permanent activation. Full product keys are never displayed or logged (OEM keys are masked to last-5 for privacy).
2. Perpetual vs Subscription Separation: Explicitly separates perpetual Office licenses (LTSC/Retail) from Microsoft 365 Click-to-Run vNext tokens.
3. Official ODT Automation: Programmatically acquires official Microsoft setup.exe over hardened HTTPS (port 443 enforced, userinfo rejected, exact Microsoft hostname allowlist) and verifies Authenticode signatures, Microsoft root trust, and Code Signing EKU.
4. Declarative XML Builder: Generates custom deployment XML for M365 Enterprise/Business, Office 2021 LTSC Volume, Visio, and Project with granular app exclusions and Shared Computer Licensing.
5. Office Maintenance: Guided Quick Repair via Windows Settings, Online Repair via documented C2R CLI with architecture detection, and clean uninstallation with data preservation warnings.
6. Zero Activation Bypasses: No KMS emulators, no license modification scripts, no unauthorized bypasses.
7. Quality & Compatibility: 109 unit tests in Pester, 0 PSScriptAnalyzer violations, dual-compatible with Windows PowerShell 5.1 and PowerShell 7.

GitHub Repository: https://github.com/winpilot/winpilot
Documentation: https://github.com/winpilot/winpilot/blob/main/docs/QUICKSTART.md

I would love to get feedback from fellow sysadmins and PowerShell developers on the architecture, diagnostics, and deployment workflows!
```

---

## 6. Curated Beginner-Friendly Contributor Issues

Create the following issues on GitHub to invite community participation:

### Issue 1: `[docs] Add localized Quick Start guides (Spanish, German, Japanese)`
- **Labels**: `documentation`, `good first issue`
- **Description**: Translate `docs/QUICKSTART.md` into Spanish, German, or Japanese to improve international discoverability.

### Issue 2: `[enhancement] Add pending reboot check for Windows CBS servicing branch`
- **Labels**: `enhancement`, `good first issue`, `diagnostics`
- **Description**: Extend `Get-WinPilotSystemHealth` to check additional subkeys under `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`.

### Issue 3: `[testing] Add unit tests for ARM64 host architecture detection`
- **Labels**: `testing`, `good first issue`
- **Description**: Add unit tests in `tests/Unit/Core.Tests.ps1` asserting that `Get-WinPilotHost` correctly handles `PROCESSOR_ARCHITECTURE = "ARM64"`.
