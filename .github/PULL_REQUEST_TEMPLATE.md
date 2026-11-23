## Description
Brief summary of the changes introduced in this pull request and the problem they resolve.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking enhancement adding functionality)
- [ ] Documentation update (improving guides, specs, or inline comments)
- [ ] Code health / refactoring (no functional changes to public cmdlets)
- [ ] Security hardening (improving verification, sanitization, or containment)

## Affected Modules
- [ ] Core (`Host.ps1`, `AnsiUI.ps1`, `Input.ps1`, `Logger.ps1`)
- [ ] Diagnostics (`WindowsLicense.ps1`, `OfficeLicense.ps1`, `SystemHealth.ps1`)
- [ ] Office Deployment (`OdtEngine.ps1`, `XmlBuilder.ps1`, `DeployRunner.ps1`)
- [ ] Office Maintenance (`OfficeRepair.ps1`, `OfficeUpdate.ps1`, `OfficeUninstall.ps1`)
- [ ] Security & Staging (`Integrity.ps1`, `SignatureVerifier.ps1`, `SecureBootstrapper.ps1`)
- [ ] Test Suites (`tests/Unit/`)
- [ ] CI Pipeline (`.github/workflows/`)

## Verification Checklist
- [ ] All code strictly maintains **PowerShell 5.1 and PowerShell 7+ dual compatibility** (no `?:`, `??`, or `&&`/`||` syntax).
- [ ] Added or updated unit tests in `tests/Unit/`.
- [ ] Executed the full Pester test suite (`Get-ChildItem -Path tests\Unit -Filter "*.Tests.ps1" | Invoke-Pester -PassThru`) with **0 failures**.
- [ ] Executed `Invoke-ScriptAnalyzer -Path src -Recurse -Settings tests/PSScriptAnalyzerSettings.psd1` with **0 violations**.
- [ ] Validated that all destructive operations default to `[NO]` and require explicit user confirmation.
- [ ] Verified that full 25-character product keys are never displayed or logged (masked OEM keys only).
- [ ] Verified that external processes use `Invoke-WinPilotProcess` and unit tests do not launch real substitute binaries.
- [ ] Verified that downloads enforce HTTPS on port 443, reject userinfo, and enforce approved host allowlists.

## Related Issues
Closes #(issue number)
