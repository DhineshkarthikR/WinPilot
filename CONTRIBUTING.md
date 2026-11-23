# Contributing to WinPilot

Thank you for your interest in contributing to WinPilot! We welcome contributions that align with our commitment to legitimate, secure, and transparent Windows and Microsoft Office management.

---

## Non-Negotiable Invariants & Security Guardrails

Before contributing code, please review our core architectural invariants:

1. **Zero Unauthorized Activation**: WinPilot strictly prohibits unauthorized activation mechanisms, KMS emulation, licensing tampering, or digital license bypasses. All licensing diagnostics must query official, supported Microsoft interfaces (`SoftwareLicensingProduct`, CIM/WMI, Click-to-Run registries) in read-only mode.
2. **First-Party Tooling Only**: Office deployment and uninstallation must rely exclusively on official Microsoft Office Deployment Tool (ODT) binaries (`setup.exe`) obtained from official Microsoft CDN endpoints.
3. **PowerShell 5.1 & 7+ Dual Compatibility**: All source code must run natively on Windows PowerShell 5.1 (the default engine on Windows 10 and 11) while remaining fully compatible with PowerShell Core (PowerShell 7+). Avoid PowerShell 7-exclusive operators:
   - Do NOT use the ternary operator (`condition ? true : false`).
   - Do NOT use the null-coalescing operator (`??` or `??=`).
   - Do NOT use pipeline chain operators (`&&` or `||`).
4. **Licensing Privacy**: Full 25-character product keys must never be captured, displayed, or logged. Embedded OEM BIOS/UEFI keys must be masked (`XXXXX-XXXXX-XXXXX-XXXXX-<last5>`).
5. **Safety by Default**: Destructive or system-modifying operations must require explicit user confirmation via `Confirm-WinPilotAction`, defaulting to `[NO]`. High-risk operations require explicit typed `YES`.
6. **Isolated Process Execution**: External binaries must be launched through `Invoke-WinPilotProcess`. Unit tests must mock this wrapper and must never launch real substitute binaries (such as `powershell.exe` or `notepad.exe`).
7. **Hardened Network Streaming**: Downloads must enforce HTTPS on port 443, reject URLs with userinfo credentials, limit redirects to 5 hops, and validate target hosts against approved Microsoft hostnames.

---

## Development Environment Setup

1. **Prerequisites**:
   - Windows 10 (Build 1809+) or Windows 11.
   - Windows PowerShell 5.1 and/or PowerShell Core 7+.
   - Git for Windows.

2. **Fork and Clone**:
   ```powershell
   git clone https://github.com/<your-username>/winpilot.git
   cd winpilot
   ```

3. **Verify Local Environment**:
   Ensure execution policy permits running local scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
   Import-Module .\src\WinPilot.psd1 -Force
   ```

---

## Testing & Quality Assurance

All pull requests must pass the complete automated test suite and static analysis checks before merging.

### Running Pester Unit Tests

WinPilot uses Pester for unit testing. The test discovery command must use `-Filter "*.Tests.ps1"`:

```powershell
$testFiles = Get-ChildItem -Path "tests\Unit" -Filter "*.Tests.ps1" | Select-Object -ExpandProperty FullName
$results = Invoke-Pester -Script $testFiles -PassThru

if ($results.FailedCount -gt 0) {
    Write-Error "Unit tests failed: $($results.FailedCount)"
} else {
    Write-Host "All $($results.TotalCount) tests passed!" -ForegroundColor Green
}
```

### Running Static Analysis (PSScriptAnalyzer)

All code under `src/` must adhere to our strict PSScriptAnalyzer configuration:

```powershell
Import-Module PSScriptAnalyzer
$analyzerResults = Invoke-ScriptAnalyzer -Path '.\src' -Recurse -Settings '.\tests\PSScriptAnalyzerSettings.psd1'

if ($analyzerResults) {
    $analyzerResults | Format-Table -AutoSize
    throw "PSScriptAnalyzer detected $($analyzerResults.Count) violation(s)."
} else {
    Write-Host "PSScriptAnalyzer passed: 0 violations." -ForegroundColor Green
}
```

---

## Contribution Workflow

1. **Create a Topic Branch**:
   ```powershell
   git checkout -b feature/my-enhancement
   ```

2. **Implement Changes**:
   - Add module code in `src/Modules/<Subsystem>/`.
   - Update `src/WinPilot.psd1` (and `src/WinPilot.psm1` if exporting public functions).
   - Add comprehensive unit tests in `tests/Unit/`.

3. **Commit Conventions**:
   Use structured commit messages adhering to standard format:
   - `feat(module): add new diagnostic check for component store`
   - `fix(deploy): resolve redirect validation edge case`
   - `docs(readme): update quickstart examples`
   - `test(security): add negative tests for unapproved port rejection`

4. **Submit a Pull Request**:
   - Fill out the provided [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
   - Ensure GitHub Actions CI passes across both Windows PowerShell 5.1 and PowerShell 7.
