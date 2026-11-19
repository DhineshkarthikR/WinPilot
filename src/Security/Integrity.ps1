<#
.SYNOPSIS
    WinPilot Cryptographic Hash and Integrity Verification Module.

.DESCRIPTION
    Provides SHA-256 calculation, integrity verification against known hashes,
    and manifest verification for downloaded payloads and internal files.
#>

function Get-WinPilotFileHash {
    <#
    .SYNOPSIS
        Computes the SHA-256 cryptographic hash of a specified file.
    .PARAMETER Path
        Path to the target file.
    .OUTPUTS
        [string] Uppercase hexadecimal SHA-256 hash.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]"File not found: $Path"
    }

    $stream = $null
    $sha256 = $null
    try {
        $stream = [System.IO.File]::OpenRead((Resolve-Path -Path $Path).ProviderPath)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($stream)
        $builder = New-Object System.Text.StringBuilder
        foreach ($b in $hashBytes) {
            [void]$builder.Append($b.ToString("X2"))
        }
        return $builder.ToString()
    }
    finally {
        if ($sha256) { $sha256.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function Test-WinPilotFileIntegrity {
    <#
    .SYNOPSIS
        Compares the SHA-256 hash of a file against an expected hash value.
    .PARAMETER Path
        Path to the file to verify.
    .PARAMETER ExpectedHash
        Expected 64-character hexadecimal SHA-256 hash.
    .OUTPUTS
        [bool] True if the hash matches exactly, False otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$ExpectedHash
    )

    try {
        $actualHash = Get-WinPilotFileHash -Path $Path
        $normalizedExpected = $ExpectedHash.Trim().ToUpperInvariant()
        $normalizedActual = $actualHash.Trim().ToUpperInvariant()

        $isMatch = ($normalizedActual -eq $normalizedExpected)

        if ($isMatch) {
            Write-WinPilotLog -Level "INFO" -Component "Security" -Message "Integrity verified for $(Split-Path $Path -Leaf) (SHA-256: $actualHash)"
            return $true
        }
        else {
            Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "INTEGRITY MISMATCH for $(Split-Path $Path -Leaf)! Expected: $normalizedExpected, Actual: $normalizedActual"
            return $false
        }
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Integrity check failed with error: $($_.Exception.Message)"
        return $false
    }
}

function Test-WinPilotManifest {
    <#
    .SYNOPSIS
        Validates all files listed in a JSON manifest against their expected SHA-256 hashes.
    .PARAMETER ManifestPath
        Path to the JSON manifest file.
    .PARAMETER BaseDirectory
        Base directory containing the files referenced by relative paths in the manifest.
    .OUTPUTS
        [PSCustomObject] Summary with AllValid (bool), CheckedCount, and FailedFiles.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$BaseDirectory
    )

    if (-not (Test-Path -Path $ManifestPath)) {
        throw [System.IO.FileNotFoundException]"Manifest file not found: $ManifestPath"
    }

    $rawJson = [System.IO.File]::ReadAllText($ManifestPath, [System.Text.Encoding]::UTF8)
    $manifest = $rawJson | ConvertFrom-Json

    $failedFiles = New-Object System.Collections.Generic.List[string]
    $checkedCount = 0

    foreach ($entry in $manifest.files) {
        $filePath = [System.IO.Path]::Combine($BaseDirectory, $entry.path)
        $expectedHash = $entry.sha256

        $checkedCount++
        if (-not (Test-Path -Path $filePath)) {
            $failedFiles.Add("$($entry.path) (File Missing)")
            continue
        }

        $isValid = Test-WinPilotFileIntegrity -Path $filePath -ExpectedHash $expectedHash
        if (-not $isValid) {
            $failedFiles.Add("$($entry.path) (Hash Mismatch)")
        }
    }

    $allValid = ($failedFiles.Count -eq 0 -and $checkedCount -gt 0)
    return [PSCustomObject]@{
        AllValid     = $allValid
        CheckedCount = $checkedCount
        FailedCount  = $failedFiles.Count
        FailedFiles  = $failedFiles.ToArray()
    }
}
