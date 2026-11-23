# Getting Support with WinPilot

Welcome to the WinPilot support guide. We are committed to helping users and administrators diagnose, deploy, and manage their Windows and Office environments effectively.

---

## Where to Look First

Before opening a new ticket, please check the existing documentation and discussions:

1. **[README.md](README.md)**: Overview of features, requirements, and interactive menus.
2. **[Quick Start Guide](docs/QUICKSTART.md)**: Step-by-step setup and first-use instructions.
3. **[Architecture Specification](docs/ARCHITECTURE.md)**: Deep dive into subsystem designs and security invariants.
4. **[GitHub Issues](https://github.com/winpilot/winpilot/issues)**: Check open and resolved issues for similar problems.
5. **[GitHub Discussions](https://github.com/winpilot/winpilot/discussions)**: Community Q&A, installation guidance, and troubleshooting tips.

---

## Community Discussion Categories

When using GitHub Discussions, please categorize your post appropriately:

- **Announcements**: Project news, milestone completions, and release highlights (Maintainer posts).
- **Q&A**: Troubleshooting questions, syntax guidance, and deployment assistance.
- **Ideas**: Proposals for new diagnostic cmdlets, ODT features, or UI improvements.
- **Development**: Technical discussions regarding PowerShell 5.1/7 compatibility, Pester tests, and module design.
- **General**: Open conversations about Windows systems administration and tooling.

---

## Filing an Issue

If you have confirmed a bug or want to submit an actionable feature request:

- **Bug Reports**: Use the [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.md). Please include PowerShell version, Windows build number, terminal type, and relevant sanitized audit log excerpts from `%ProgramData%\WinPilot\Logs\`.
- **Feature Requests**: Use the [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.md) with details on the problem, proposed solution, and supported Microsoft APIs.
- **Security Vulnerabilities**: Follow the confidential disclosure procedure in [SECURITY.md](SECURITY.md).

---

## Scope of Support

WinPilot is an open-source project maintained by volunteer contributors:

- **Supported**: Issues relating to WinPilot cmdlets, TUI rendering, ODT XML generation, Click-to-Run repair triggers, and diagnostic audits on supported Windows 10/11 versions.
- **Not Supported**: Troubleshooting unauthorized third-party activation tools, modified Windows installations, corrupted third-party registry hacks, or enterprise network proxy outages beyond standard HTTPS connectivity.
