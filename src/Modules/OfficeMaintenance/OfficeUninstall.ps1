<#
.SYNOPSIS
    WinPilot Safe Microsoft Office Uninstallation & Removal Subsystem.

.DESCRIPTION
    Provides official, supported uninstallation of Microsoft Office using the
    Office Deployment Tool (ODT) Remove schema. Displays detected products, enforces
    strict typed confirmation, preserves user documents and data, and logs all events.
#>

function New-WinPilotOfficeRemovalXml {
    <#
    .SYNOPSIS
        Generates an official ODT removal configuration XML using System.Xml.XmlWriter.
    .PARAMETER ProductIds
        Array of specific products to remove. If empty or omitted, generates <Remove All="TRUE" />.
    .PARAMETER DisplayLevel
        UI visibility level ('Full' or 'None'). Defaults to 'Full'.
    .PARAMETER OutputPath
        Optional file path to write the removal XML.
    .OUTPUTS
        [string] Compiled XML string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ProductIds = @(),

        [Parameter(Mandatory = $false)]
        [ValidateSet("Full", "None")]
        [string]$DisplayLevel = "Full",

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    $stringWriter = New-Object System.IO.StringWriter
    $xmlSettings = New-Object System.Xml.XmlWriterSettings
    $xmlSettings.Indent = $true
    $xmlSettings.OmitXmlDeclaration = $true
    $xmlSettings.Encoding = [System.Text.Encoding]::UTF8

    $writer = [System.Xml.XmlWriter]::Create($stringWriter, $xmlSettings)

    try {
        $writer.WriteStartElement("Configuration")

        if ($ProductIds.Count -eq 0) {
            # <Remove All="TRUE" />
            $writer.WriteStartElement("Remove")
            $writer.WriteAttributeString("All", "TRUE")
            $writer.WriteEndElement() # Remove
        }
        else {
            $writer.WriteStartElement("Remove")
            foreach ($pid in $ProductIds) {
                if (-not [string]::IsNullOrEmpty($pid)) {
                    $writer.WriteStartElement("Product")
                    $writer.WriteAttributeString("ID", $pid.Trim())
                    $writer.WriteEndElement() # Product
                }
            }
            $writer.WriteEndElement() # Remove
        }

        # <Display Level="..." AcceptEULA="TRUE" />
        $writer.WriteStartElement("Display")
        $writer.WriteAttributeString("Level", $DisplayLevel)
        $writer.WriteAttributeString("AcceptEULA", "TRUE")
        $writer.WriteEndElement() # Display

        $writer.WriteEndElement() # Configuration
        $writer.Flush()
    }
    finally {
        $writer.Close()
    }

    $xmlContent = $stringWriter.ToString()

    if (-not [string]::IsNullOrEmpty($OutputPath)) {
        $parent = Split-Path -Path $OutputPath -Parent
        if (-not [string]::IsNullOrEmpty($parent) -and -not (Test-Path -Path $parent)) {
            [void](New-Item -ItemType Directory -Path $parent -Force)
        }
        [System.IO.File]::WriteAllText($OutputPath, $xmlContent, [System.Text.Encoding]::UTF8)
    }

    return $xmlContent
}

function Invoke-WinPilotOfficeUninstall {
    <#
    .SYNOPSIS
        Executes a safe, verified uninstallation of Microsoft Office via official ODT.
    .PARAMETER SetupPath
        Optional path to verified official setup.exe. If omitted, acquired via Get-WinPilotOdt.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SetupPath
    )

    # Step 1: Detect installed Office products to show user exactly what will be removed
    $subInfo = Get-WinPilotOfficeSubscriptionStatus
    $detectedProducts = $subInfo.ProductReleaseIds

    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host "  OFFICE UNINSTALLATION - IMPACT ASSESSMENT" -ForegroundColor Red
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host "  Installed Products Detected : $detectedProducts" -ForegroundColor White
    Write-Host "  Installed Version           : $($subInfo.Version) ($($subInfo.Architecture))" -ForegroundColor Gray
    Write-Host "  Update Channel              : $($subInfo.UpdateChannel)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  SAFETY ASSURANCE:" -ForegroundColor Green
    Write-Host "  - Personal documents, Word/Excel files, and Outlook PST/OST data will be preserved." -ForegroundColor White
    Write-Host "  - Non-Office registry branches and unrelated directories will NOT be touched." -ForegroundColor White
    Write-Host "  - NOTICE: Automatic uninstallation rollback is NOT guaranteed once execution starts." -ForegroundColor Yellow
    Write-Host ""

    # Record Pre-Operation State
    Write-WinPilotLog -Level "AUDIT" -Component "OfficeUninstall" -Message "Pre-Uninstall State: Products=$detectedProducts, Version=$($subInfo.Version), Channel=$($subInfo.UpdateChannel)"

    # Require explicit typed confirmation
    $isConfirmed = Confirm-WinPilotAction -ActionName "Completely Uninstall Microsoft Office ($detectedProducts)" -RiskLevel "Critical" -RequiresTypedConfirmation
    if (-not $isConfirmed) {
        Write-WinPilotLog -Level "AUDIT" -Component "OfficeUninstall" -Message "User cancelled Office uninstallation."
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            StatusMessage = "Operation cancelled by user."
        }
    }

    # Acquire and verify ODT setup.exe
    if ([string]::IsNullOrEmpty($SetupPath) -or -not (Test-Path -Path $SetupPath)) {
        Show-WinPilotBanner -Message "Acquiring verified official ODT setup.exe for uninstallation..." -Type "Info"
        $SetupPath = Get-WinPilotOdt
    }

    $isAuthentic = Test-WinPilotAuthenticode -Path $SetupPath -ExpectedSubject "Microsoft Corporation"
    if (-not $isAuthentic) {
        Write-WinPilotLog -Level "ERROR" -Component "OfficeUninstall" -Message "SECURITY ALERT: setup.exe failed Authenticode check. Aborting uninstall."
        throw "Security Error: setup.exe failed Authenticode verification."
    }

    $tempXml = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "ODT", "remove_config_$([Guid]::NewGuid().ToString('N')).xml")
    New-WinPilotOfficeRemovalXml -OutputPath $tempXml | Out-Null

    try {
        Write-WinPilotLog -Level "INFO" -Component "OfficeUninstall" -Message "Executing ODT removal with configuration: $tempXml"
        Show-WinPilotBanner -Message "Executing official Office uninstallation..." -Type "Info"

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $SetupPath
        $pinfo.Arguments = "/configure `"$tempXml`""
        $pinfo.UseShellExecute = $false

        $process = [System.Diagnostics.Process]::Start($pinfo)
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 500
        }

        $exitCode = $process.ExitCode
        $process.Dispose()

        $isSuccess = ($exitCode -eq 0)
        $msg = if ($isSuccess) {
            "Office uninstallation completed successfully."
        } else {
            "Office uninstallation completed with exit code: $exitCode."
        }

        Write-WinPilotLog -Level $(if ($isSuccess) { "INFO" } else { "WARN" }) -Component "OfficeUninstall" -Message $msg

        if ($isSuccess) {
            Show-WinPilotBanner -Message $msg -Type "Success"
        } else {
            Show-WinPilotBanner -Message $msg -Type "Warning"
            Write-Host "  Recovery Instructions: If partial remnants remain, restart the computer and run WinPilot Office Deployment to reinstall." -ForegroundColor Yellow
        }

        return [PSCustomObject]@{
            Success       = $isSuccess
            ExitCode      = $exitCode
            StatusMessage = $msg
        }
    }
    catch {
        Write-WinPilotLog -Level "ERROR" -Component "OfficeUninstall" -Message "Uninstallation execution exception: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success       = $false
            ExitCode      = -1
            StatusMessage = "Uninstallation failed: $($_.Exception.Message)"
        }
    }
    finally {
        if (Test-Path -Path $tempXml) {
            Remove-Item -Path $tempXml -Force -ErrorAction SilentlyContinue
        }
    }
}
