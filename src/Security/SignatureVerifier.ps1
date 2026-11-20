<#
.SYNOPSIS
    WinPilot Authenticode Digital Signature Verification Module.

.DESCRIPTION
    Provides verification of Authenticode digital signatures for external binaries
    and PowerShell scripts, ensuring only valid and trusted publisher assets execute.
#>

function Get-WinPilotSignature {
    <#
    .SYNOPSIS
        Retrieves the Authenticode signature of a specified file.
    .PARAMETER Path
        Path to the file to inspect.
    .OUTPUTS
        [System.Management.Automation.Signature]
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Signature])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]"File not found: $Path"
    }

    return Get-AuthenticodeSignature -FilePath (Resolve-Path -Path $Path).ProviderPath
}

function Test-WinPilotAuthenticode {
    <#
    .SYNOPSIS
        Verifies that a file's Authenticode signature is Valid and optionally matches expected publisher.
    .PARAMETER Path
        Path to the binary or script to verify.
    .PARAMETER ExpectedSubject
        Optional expected publisher subject string (e.g. 'CN=Microsoft Corporation').
    .OUTPUTS
        [bool] True if signature is valid and publisher matches, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$ExpectedSubject
    )

    try {
        $sig = Get-WinPilotSignature -Path $Path

        if ($sig.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
            Write-WinPilotLog -Level "WARN" -Component "Security" -Message "Authenticode check failed for $(Split-Path $Path -Leaf): Status is $($sig.Status)"
            return $false
        }

        # Validate X.509 Certificate Chain Trust
        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
        $chainValid = $chain.Build($sig.SignerCertificate)
        if (-not $chainValid) {
            Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Certificate chain trust check failed for $(Split-Path $Path -Leaf)"
            return $false
        }

        if (-not [string]::IsNullOrEmpty($ExpectedSubject)) {
            $subject = $sig.SignerCertificate.Subject
            if ($subject -notlike "*$ExpectedSubject*") {
                Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Publisher mismatch for $(Split-Path $Path -Leaf)! Expected: $ExpectedSubject, Actual: $subject"
                return $false
            }
        }

        Write-WinPilotLog -Level "INFO" -Component "Security" -Message "Authenticode signature verified valid for $(Split-Path $Path -Leaf)"
        return $true
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Signature verification encountered exception: $($_.Exception.Message)"
        return $false
    }
}
