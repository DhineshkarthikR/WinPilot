# Security Policy

The WinPilot project takes security, cryptographic integrity, and privacy very seriously. We appreciate the efforts of security researchers and developers in identifying and responsibly reporting vulnerabilities.

---

## Supported Versions

Security updates, bug fixes, and defensive patches are actively provided for the following releases:

| Version | Supported | Notes |
| :--- | :---: | :--- |
| **v0.4.x** | **Yes** | Current active release branch |
| < v0.4.0 | No | Legacy milestone scaffolds |

---

## Reporting a Vulnerability

> [!IMPORTANT]
> **Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security flaw, vulnerability, or potential exploit in WinPilot, please report it privately:

1. **GitHub Private Security Advisory (Preferred)**:
   - Navigate to the **Security** tab of the WinPilot repository on GitHub.
   - Click on **Advisories** and select **Report a vulnerability**.
   - Provide a detailed description of the vulnerability, reproduction steps, affected cmdlets, and potential impact.

2. **Direct Maintainer Contact**:
   - If GitHub Advisories are unavailable, open a confidential issue labeled `[SECURITY-CONFIDENTIAL]` requesting private coordination before sharing technical details.

---

## Response and Disclosure Timelines

- **Initial Acknowledgment**: Within 48 hours of receipt.
- **Triage & Reproduction**: Within 5 business days.
- **Remediation & Patch**: Timeline agreed upon based on severity (typically 14–30 days).
- **Public Disclosure**: Coordinated after the fix has been merged and a patched release has been tagged.

---

## Scope & Security Architecture Commitments

WinPilot adheres to the following strict security design patterns:

- **Strict Authenticode Verification**: All external binaries acquired by WinPilot must possess a valid Authenticode signature from `CN=Microsoft Corporation, O=Microsoft Corporation`, root trust to Microsoft Root Authority, and Code Signing EKU (`1.3.6.1.5.5.7.3.3`).
- **Hardened Network Streaming**: Downloads strictly enforce HTTPS on port 443, reject URLs containing userinfo credentials, reject unapproved subdomains, limit redirects to 5 hops, and stream directly from validated HTTP 200 responses.
- **Licensing Privacy by Design**: Complete 25-character Windows product keys are never displayed or stored in logs. OEM keys are masked (`XXXXX-XXXXX-XXXXX-XXXXX-<last5>`).
- **Process Isolation Wrapper**: External processes are executed via `Invoke-WinPilotProcess` with monitored exit codes and clean timeout handling.
- **Zero Activation Tampering**: WinPilot never includes, supports, or permits activation bypasses, KMS emulation, or unauthorized license injection.
