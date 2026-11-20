<#
.SYNOPSIS
    WinPilot Authenticode Digital Signature Verification Module.

.DESCRIPTION
    Provides verification of Authenticode digital signatures for external binaries
    and PowerShell scripts, ensuring only valid and trusted publisher assets execute.
#>

function Get-WinPilotX500Attribute {
    <#
    .SYNOPSIS
        Extracts a specific attribute (e.g. CN, O, C) from an X.500 Distinguished Name string.
    .PARAMETER DistinguishedName
        The X.500 distinguished name string.
    .PARAMETER AttributeName
        The RDN attribute name to extract (e.g. "CN", "O").
    .OUTPUTS
        [string] Attribute value, or $null if not found.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$DistinguishedName,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$AttributeName
    )

    if ([string]::IsNullOrEmpty($DistinguishedName)) { return $null }
    $pattern = "(?:^|,\s*)" + [regex]::Escape($AttributeName) + "\s*=\s*([^,]+)"
    $match = [regex]::Match($DistinguishedName, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim().Trim('"')
    }
    return $null
}

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

        # Validate Code Signing Enhanced Key Usage (OID 1.3.6.1.5.5.7.3.3)
        $hasCodeSigningEku = $false
        foreach ($ext in $sig.SignerCertificate.Extensions) {
            if ($ext -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
                foreach ($usage in $ext.EnhancedKeyUsages) {
                    if ($usage.Value -eq "1.3.6.1.5.5.7.3.3") {
                        $hasCodeSigningEku = $true
                        break
                    }
                }
            }
        }
        if (-not $hasCodeSigningEku) {
            Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Certificate lacks required Code Signing EKU (1.3.6.1.5.5.7.3.3) for $(Split-Path $Path -Leaf)"
            return $false
        }

        # 4. Strict Identity Validation: Enforce Exact X.500 RDN Attributes
        if (-not [string]::IsNullOrEmpty($ExpectedSubject)) {
            $leafCn = Get-WinPilotX500Attribute -DistinguishedName $sig.SignerCertificate.Subject -AttributeName "CN"
            $leafOrg = Get-WinPilotX500Attribute -DistinguishedName $sig.SignerCertificate.Subject -AttributeName "O"
            $expectedClean = $ExpectedSubject.Replace("CN=", "").Replace("O=", "").Trim().Trim('"')

            # Verify exact equality against leaf Common Name (CN) or Organization (O)
            $exactMatch = ($leafCn -eq $expectedClean) -or ($leafOrg -eq $expectedClean)
            if (-not $exactMatch) {
                Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Strict publisher mismatch for $(Split-Path $Path -Leaf)! Expected: '$expectedClean', Actual CN: '$leafCn', Org: '$leafOrg'"
                return $false
            }

            # Enforce that Microsoft binaries terminate in an authentic Microsoft Root Authority
            if ($expectedClean -eq "Microsoft Corporation" -or $expectedClean -eq "Microsoft Windows") {
                $rootCert = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate
                $rootCn = Get-WinPilotX500Attribute -DistinguishedName $rootCert.Subject -AttributeName "CN"
                $rootOrg = Get-WinPilotX500Attribute -DistinguishedName $rootCert.Subject -AttributeName "O"

                $validRootCns = @(
                    "Microsoft Root Certificate Authority",
                    "Microsoft Root Certificate Authority 2010",
                    "Microsoft Root Certificate Authority 2011",
                    "Microsoft Root Authority"
                )

                if ($rootOrg -ne "Microsoft Corporation" -or $rootCn -notin $validRootCns) {
                    Write-WinPilotLog -Level "ERROR" -Component "Security" -Message "Untrusted root authority for $(Split-Path $Path -Leaf)! Root CN: '$rootCn', Root Org: '$rootOrg'"
                    return $false
                }
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
