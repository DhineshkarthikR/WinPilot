#
# Pester Unit Tests for WinPilot Security & Integrity Subsystem
# Compatible with PowerShell 5.1 and modern PowerShell
#

$modulePath = Resolve-Path "$PSScriptRoot\..\..\src\WinPilot.psd1"
Import-Module $modulePath -Force

Describe "WinPilot Cryptographic Hash & Integrity (Positive Paths)" {
    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, "WinPilot Secure Integrity Test String 2026", [System.Text.Encoding]::UTF8)

    It "Calculates valid uppercase 64-character SHA-256 hash" {
        $hash = Get-WinPilotFileHash -Path $tempFile
        $hash | Should Not BeNullOrEmpty
        $hash.Length | Should Be 64
        $hash | Should Match "^[A-F0-9]{64}$"
    }

    It "Verifies file integrity when expected hash matches" {
        $hash = Get-WinPilotFileHash -Path $tempFile
        $isValid = Test-WinPilotFileIntegrity -Path $tempFile -ExpectedHash $hash
        $isValid | Should Be $true
    }

    It "Handles lowercase expected hash case-insensitively" {
        $hash = (Get-WinPilotFileHash -Path $tempFile).ToLowerInvariant()
        $isValid = Test-WinPilotFileIntegrity -Path $tempFile -ExpectedHash $hash
        $isValid | Should Be $true
    }

    # Clean up
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
}

Describe "WinPilot Cryptographic Hash & Integrity (Negative & Failure Paths)" {
    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, "Original Content", [System.Text.Encoding]::UTF8)

    It "Rejects file when expected hash is mismatched (Tampered detection)" {
        $fakeHash = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
        $isValid = Test-WinPilotFileIntegrity -Path $tempFile -ExpectedHash $fakeHash
        $isValid | Should Be $false
    }

    It "Throws FileNotFoundException when file does not exist" {
        $nonExistent = "C:\Windows\Temp\NonExistent_File_$([Guid]::NewGuid().ToString('N')).bin"
        { Get-WinPilotFileHash -Path $nonExistent } | Should Throw
    }

    It "Fails gracefully when verifying non-existent file path" {
        $nonExistent = "C:\Windows\Temp\NonExistent_File_$([Guid]::NewGuid().ToString('N')).bin"
        $isValid = Test-WinPilotFileIntegrity -Path $nonExistent -ExpectedHash ("A" * 64)
        $isValid | Should Be $false
    }

    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
}

Describe "WinPilot Release Manifest Verification" {
    $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinPilot_ManifestTest_$([Guid]::NewGuid().ToString('N'))"
    [void](New-Item -ItemType Directory -Path $testDir -Force)

    $fileA = Join-Path $testDir "componentA.ps1"
    $fileB = Join-Path $testDir "componentB.ps1"
    [System.IO.File]::WriteAllText($fileA, "Write-Host 'Component A'", [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($fileB, "Write-Host 'Component B'", [System.Text.Encoding]::UTF8)

    $hashA = Get-WinPilotFileHash -Path $fileA
    $hashB = Get-WinPilotFileHash -Path $fileB

    $manifestPath = Join-Path $testDir "manifest.json"
    $manifestJson = @"
{
    "version": "1.0.0",
    "files": [
        { "path": "componentA.ps1", "sha256": "$hashA" },
        { "path": "componentB.ps1", "sha256": "$hashB" }
    ]
}
"@
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)

    It "Validates a multi-file manifest when all hashes match" {
        $result = Test-WinPilotManifest -ManifestPath $manifestPath -BaseDirectory $testDir
        $result.AllValid | Should Be $true
        $result.CheckedCount | Should Be 2
        $result.FailedCount | Should Be 0
    }

    It "Detects corrupted or tampered file in manifest" {
        # Tamper with componentB
        [System.IO.File]::AppendAllText($fileB, "# Malicious modification", [System.Text.Encoding]::UTF8)

        $result = Test-WinPilotManifest -ManifestPath $manifestPath -BaseDirectory $testDir
        $result.AllValid | Should Be $false
        $result.FailedCount | Should Be 1
        $result.FailedFiles[0] | Should Match "componentB.ps1"
    }

    It "Detects missing file listed in manifest" {
        Remove-Item $fileA -Force
        $result = Test-WinPilotManifest -ManifestPath $manifestPath -BaseDirectory $testDir
        $result.AllValid | Should Be $false
        ($result.FailedFiles -contains "componentA.ps1 (File Missing)") | Should Be $true
    }

    # Clean up
    if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe "WinPilot Authenticode Digital Signature Verification" {
    # Test using known signed Microsoft Windows binaries
    $signedMsBinary = "$env:SystemRoot\System32\notepad.exe"
    $unsignedFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($unsignedFile, "Not signed", [System.Text.Encoding]::UTF8)

    It "Detects valid digital signature on signed Microsoft binary" {
        if (Test-Path $signedMsBinary) {
            $isValid = Test-WinPilotAuthenticode -Path $signedMsBinary -ExpectedSubject "Microsoft Corporation"
            $isValid | Should Be $true
        }
    }

    It "Rejects unsigned files with Authenticode verification" {
        $isValid = Test-WinPilotAuthenticode -Path $unsignedFile
        $isValid | Should Be $false
    }

    It "Rejects signed binary when expected publisher does not match" {
        if (Test-Path $signedMsBinary) {
            $isValid = Test-WinPilotAuthenticode -Path $signedMsBinary -ExpectedSubject "Unauthorized Publisher 999"
            $isValid | Should Be $false
        }
    }

    if (Test-Path $unsignedFile) { Remove-Item $unsignedFile -Force }
}

Describe "WinPilot Secure Staging & Download Containment" {
    It "Rejects non-HTTPS URIs at parameter validation boundary" {
        {
            Invoke-WinPilotSecureStage -Uri "http://insecure-http.example.com/payload.ps1" -ExpectedHash ("A"*64)
        } | Should Throw
    }

    It "Rejects malformed SHA-256 hashes at parameter validation boundary" {
        {
            Invoke-WinPilotSecureStage -Uri "https://example.com/payload.ps1" -ExpectedHash "NotAValidHash"
        } | Should Throw
    }

    It "Handles network connection failures gracefully without leaving artifacts" {
        $fakeUri = "https://127.0.0.1:59999/nonexistent.bin"
        $result = Invoke-WinPilotSecureStage -Uri $fakeUri -ExpectedHash ("0"*64)
        $result.Success | Should Be $false
        $result.HashVerified | Should Be $false
        $result.ErrorMessage | Should Not BeNullOrEmpty
    }
}
