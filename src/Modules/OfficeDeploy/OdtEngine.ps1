<#
.SYNOPSIS
    WinPilot Official Microsoft Office Deployment Tool (ODT) Downloader & Verifier.

.DESCRIPTION
    Safely downloads the official Office Deployment Tool exclusively from Microsoft CDN,
    enforces TLS 1.2+, verifies Authenticode digital signatures against Microsoft Corporation,
    extracts setup.exe, and rejects any unverified, modified, or unsigned binaries.
#>

$script:DefaultOdtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool.exe"

function Get-WinPilotOdt {
    <#
    .SYNOPSIS
        Downloads and verifies the official Microsoft Office Deployment Tool (setup.exe).
    .PARAMETER TargetDirectory
        Target directory to store verified setup.exe. Defaults to %TEMP%\WinPilot\ODT.
    .PARAMETER DownloadUrl
        Official Microsoft download URL. Restricted to Microsoft domains.
    .OUTPUTS
        [string] Absolute path to verified setup.exe.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TargetDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -notmatch "^https://(download\.microsoft\.com|go\.microsoft\.com)/") {
                throw "Security Violation: ODT must be downloaded exclusively from official Microsoft domains (download.microsoft.com or go.microsoft.com)."
            }
            return $true
        })]
        [string]$DownloadUrl = $script:DefaultOdtUrl
    )

    Write-WinPilotLog -Level "INFO" -Component "OfficeDeploy" -Message "Initiating ODT acquisition from official source: $DownloadUrl"

    if ([string]::IsNullOrEmpty($TargetDirectory)) {
        $TargetDirectory = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "ODT")
    }

    if (-not (Test-Path -Path $TargetDirectory)) {
        [void](New-Item -ItemType Directory -Path $TargetDirectory -Force)
    }

    $existingSetup = [System.IO.Path]::Combine($TargetDirectory, "setup.exe")
    if (Test-Path -Path $existingSetup) {
        # Check if existing setup.exe is already authentic
        $isExistingValid = Test-WinPilotAuthenticode -Path $existingSetup -ExpectedSubject "Microsoft Corporation"
        if ($isExistingValid) {
            Write-WinPilotLog -Level "INFO" -Component "OfficeDeploy" -Message "Existing setup.exe verified with valid Microsoft signature: $existingSetup"
            return $existingSetup
        }
        else {
            Write-WinPilotLog -Level "WARN" -Component "OfficeDeploy" -Message "Existing setup.exe signature invalid or untrusted. Deleting and re-acquiring."
            Remove-Item -Path $existingSetup -Force -ErrorAction SilentlyContinue
        }
    }

    # Enforce modern secure TLS protocols
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $tempArchive = [System.IO.Path]::Combine($TargetDirectory, "officedeploymenttool_$([Guid]::NewGuid().ToString('N')).exe")

    try {
        Write-WinPilotLog -Level "INFO" -Component "OfficeDeploy" -Message "Downloading ODT package to $tempArchive"

        # Enforce exact hostname allowlist
        $approvedHosts = @("download.microsoft.com", "officecdn.microsoft.com", "go.microsoft.com")

        # Validate initial URL
        $initUri = $null
        try {
            $initUri = [System.Uri]$DownloadUrl
        }
        catch {
            throw "Security Alert: Initial download URL is not a valid URI: $DownloadUrl"
        }

        if ($initUri.Scheme -ne "https") {
            throw "Security Alert: Initial download URL must use secure HTTPS: $DownloadUrl"
        }
        if ($initUri.Host.ToLowerInvariant() -notin $approvedHosts) {
            throw "Security Alert: Initial download host '$($initUri.Host)' is not an approved Microsoft host ($($approvedHosts -join ', ')): $DownloadUrl"
        }

        # Follow redirects securely and stream directly from validated response in a single HTTP operation
        $req = [System.Net.HttpWebRequest]::Create($DownloadUrl)
        $req.AllowAutoRedirect = $true
        $req.MaximumAutomaticRedirections = 5
        $req.Timeout = 60000
        $req.UserAgent = "WinPilot/0.4.0 (Windows NT; Microsoft ODT Downloader)"

        $res = $req.GetResponse()
        try {
            $finalUri = $res.ResponseUri

            # Validate final URI
            if ($finalUri.Scheme -ne "https") {
                throw "Security Alert: Final download URL downgraded to non-HTTPS: $($finalUri.AbsoluteUri)"
            }

            $finalHost = $finalUri.Host.ToLowerInvariant()
            if ($finalHost -notin $approvedHosts) {
                throw "Security Alert: Final redirect destination host '$finalHost' is not an approved Microsoft host ($($approvedHosts -join ', ')): $($finalUri.AbsoluteUri)"
            }

            if (-not $finalUri.AbsolutePath.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Security Alert: Final download URL does not target an executable (.exe) binary: $($finalUri.AbsoluteUri)"
            }

            # Stream directly from validated HTTP response to target archive (single-request pattern)
            $responseStream = $res.GetResponseStream()
            $fileStream = [System.IO.File]::Create($tempArchive)
            try {
                $buffer = New-Object byte[] 65536
                while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fileStream.Write($buffer, 0, $bytesRead)
                }
            }
            finally {
                $fileStream.Dispose()
                $responseStream.Dispose()
            }
        }
        finally {
            $res.Close()
        }

        if (-not (Test-Path -Path $tempArchive -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]"ODT download package not found on disk: $tempArchive"
        }

        # Step 1: Verify Authenticode signature of downloaded installer package
        Write-WinPilotLog -Level "INFO" -Component "OfficeDeploy" -Message "Verifying Authenticode signature of downloaded ODT package"
        $isPkgValid = Test-WinPilotAuthenticode -Path $tempArchive -ExpectedSubject "Microsoft Corporation"
        if (-not $isPkgValid) {
            # DESTROY UNTRUSTED ARTIFACT IMMEDIATELY
            Remove-Item -Path $tempArchive -Force -ErrorAction SilentlyContinue
            Write-WinPilotLog -Level "ERROR" -Component "OfficeDeploy" -Message "SECURITY ALERT: Downloaded ODT package failed Authenticode signature verification! Rejected and deleted."
            throw "Security Validation Failed: Downloaded ODT package does not possess a valid Microsoft Corporation digital signature."
        }

        # Step 2: Extract setup.exe silently
        Write-WinPilotLog -Level "INFO" -Component "OfficeDeploy" -Message "Extracting setup.exe to $TargetDirectory"
        $extractArg = "/quiet /extract:`"$TargetDirectory`""
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $tempArchive
        $pinfo.Arguments = $extractArg
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        $null = $proc.WaitForExit(60000)

        # Step 3: Verify Authenticode signature of extracted setup.exe
        if (-not (Test-Path -Path $existingSetup -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]"Extracted setup.exe was not created in target directory: $existingSetup"
        }

        $isSetupValid = Test-WinPilotAuthenticode -Path $existingSetup -ExpectedSubject "Microsoft Corporation"
        if (-not $isSetupValid) {
            Remove-Item -Path $existingSetup -Force -ErrorAction SilentlyContinue
            Write-WinPilotLog -Level "ERROR" -Component "OfficeDeploy" -Message "SECURITY ALERT: Extracted setup.exe failed Authenticode signature check! Deleted."
            throw "Security Validation Failed: Extracted setup.exe is not signed by Microsoft Corporation."
        }

        Write-WinPilotLog -Level "INFO" -Component "OfficeDeploy" -Message "ODT setup.exe successfully verified and ready: $existingSetup"
        return $existingSetup
    }
    finally {
        # Clean up temporary installer archive
        if (Test-Path -Path $tempArchive) {
            Remove-Item -Path $tempArchive -Force -ErrorAction SilentlyContinue
        }
    }
}
