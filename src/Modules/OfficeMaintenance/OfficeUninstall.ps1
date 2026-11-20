<#
.SYNOPSIS
    WinPilot Safe Microsoft Office Uninstallation & Removal Subsystem.

.DESCRIPTION
    Provides official, supported uninstallation of Microsoft Office using the
    Office Deployment Tool (ODT) Remove schema. Displays detected products, enforces
    strict typed confirmation, preserves user documents and data, and logs all events.
#>

function Get-WinPilotOfficeInstallationInventory {
    <#
    .SYNOPSIS
        Discovers installed Click-to-Run Office products, languages, architecture, and version.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $c2rReg = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    if (-not (Test-Path -Path $c2rReg)) {
        return [PSCustomObject]@{
            IsInstalled       = $false
            ProductReleaseIds = @()
            Languages         = @()
            Platform          = "Unknown"
            Version           = "Unknown"
            UpdateChannel     = "Unknown"
        }
    }

    $props = Get-ItemProperty -Path $c2rReg -ErrorAction SilentlyContinue

    $pids = @()
    if ($props.ProductReleaseIds) {
        $pids = $props.ProductReleaseIds -split "[,;]" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $langs = New-Object System.Collections.Generic.List[string]
    if ($props.ClientCulture -and $props.ClientCulture.Trim() -notin $langs) {
        $langs.Add($props.ClientCulture.Trim())
    }
    if ($props.Languages) {
        $props.Languages -split "[,;]" | ForEach-Object {
            $l = $_.Trim()
            if ($l -and $l -notin $langs) { $langs.Add($l) }
        }
    }
    if ($langs.Count -eq 0) {
        $langs.Add("en-us")
    }

    return [PSCustomObject]@{
        IsInstalled       = $true
        ProductReleaseIds = @($pids)
        Languages         = @($langs)
        Platform          = if ($props.Platform) { $props.Platform } else { "x64" }
        Version           = if ($props.VersionToReport) { $props.VersionToReport } else { "Unknown" }
        UpdateChannel     = if ($props.UpdateChannel) { $props.UpdateChannel } else { "Unknown" }
    }
}

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

    # Step 1: Detect installed Office products, languages, and architecture
    $inventory = Get-WinPilotOfficeInstallationInventory
    $detectedProducts = if ($inventory.ProductReleaseIds -and $inventory.ProductReleaseIds.Count -gt 0) {
        $inventory.ProductReleaseIds -join ", "
    } else {
        "Click-to-Run Suite / Apps"
    }
    $detectedLangs = if ($inventory.Languages -and $inventory.Languages.Count -gt 0) {
        $inventory.Languages -join ", "
    } else {
        "en-us"
    }

    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host "  OFFICE UNINSTALLATION - IMPACT ASSESSMENT" -ForegroundColor Red
    Write-Host "  ================================================================" -ForegroundColor Red
    Write-Host "  Target Architecture         : $($inventory.Platform)" -ForegroundColor White
    Write-Host "  Installed Version           : $($inventory.Version)" -ForegroundColor Gray
    Write-Host "  Update Channel              : $($inventory.UpdateChannel)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  PRODUCTS SCHEDULED FOR REMOVAL:" -ForegroundColor Yellow
    foreach ($pid in $inventory.ProductReleaseIds) {
        Write-Host "  - $pid" -ForegroundColor White
    }
    if ($inventory.ProductReleaseIds.Count -eq 0) {
        Write-Host "  - All installed Click-to-Run Office suites and standalone apps" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  LANGUAGES & PROOFING TOOLS REMOVED:" -ForegroundColor Yellow
    foreach ($lang in $inventory.Languages) {
        Write-Host "  - $lang (Language pack and proofing tools)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  SCOPE OF REMOVE ALL (<Remove All=""TRUE"" />):" -ForegroundColor Yellow
    Write-Host "  - Completely uninstalls all listed Click-to-Run Office products." -ForegroundColor White
    Write-Host "  - Removes all installed language packs, proofing tools, and fonts." -ForegroundColor White
    Write-Host "  - Removes Start Menu shortcuts, desktop icons, and shell registrations." -ForegroundColor White
    Write-Host ""
    Write-Host "  SAFETY ASSURANCE (WHAT IS PRESERVED):" -ForegroundColor Green
    Write-Host "  - Personal documents (*.docx, *.xlsx, *.pptx) are strictly preserved." -ForegroundColor White
    Write-Host "  - Outlook data files (*.pst, *.ost) and mail profiles are strictly preserved." -ForegroundColor White
    Write-Host "  - Non-Office system directories and registry keys are UNTOUCHED." -ForegroundColor White
    Write-Host "  - NOTICE: Automatic uninstallation rollback is NOT guaranteed once execution starts." -ForegroundColor Yellow
    Write-Host ""

    # Record Pre-Operation State
    Write-WinPilotLog -Level "AUDIT" -Component "OfficeUninstall" -Message "Pre-Uninstall State: Products=$detectedProducts, Languages=$detectedLangs, Version=$($inventory.Version), Platform=$($inventory.Platform), Channel=$($inventory.UpdateChannel)"

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

    $tempXml = $null
    try {
        $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "WinPilot", "ODT")
        if (-not (Test-Path -Path $tempDir)) {
            [void](New-Item -ItemType Directory -Path $tempDir -Force)
        }
        $tempXml = [System.IO.Path]::Combine($tempDir, "remove_config_$([Guid]::NewGuid().ToString('N')).xml")
        New-WinPilotOfficeRemovalXml -OutputPath $tempXml | Out-Null
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
        if ($tempXml -and (Test-Path -Path $tempXml)) {
            Remove-Item -Path $tempXml -Force -ErrorAction SilentlyContinue
        }
    }
}
