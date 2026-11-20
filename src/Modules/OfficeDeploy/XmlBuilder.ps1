<#
.SYNOPSIS
    WinPilot Dynamic Microsoft Office Deployment XML Configuration Compiler.

.DESCRIPTION
    Generates official Microsoft Office Deployment Tool (ODT) compliant configuration XML
    using System.Xml.XmlWriter. Strictly avoids string concatenation to prevent syntax
    corruption, schema non-compliance, and attribute injection.
#>

$script:SupportedProducts = @(
    "O365ProPlusRetail",       # Microsoft 365 Apps for Enterprise
    "O365BusinessRetail",      # Microsoft 365 Apps for Business
    "ProPlus2021Volume",       # Office LTSC Professional Plus 2021
    "ProPlus2024Volume",       # Office LTSC Professional Plus 2024
    "Standard2021Volume",      # Office LTSC Standard 2021
    "VisioPro2021Volume",      # Visio LTSC Professional 2021
    "VisioPro2024Volume",      # Visio LTSC Professional 2024
    "ProjectPro2021Volume",    # Project LTSC Professional 2021
    "ProjectPro2024Volume"     # Project LTSC Professional 2024
)

$script:SupportedChannels = @(
    "Current",
    "MonthlyEnterprise",
    "SemiAnnual",
    "PerpetualVL2021",
    "PerpetualVL2024",
    "BetaChannel"
)

$script:SupportedApps = @(
    "Access",
    "Excel",
    "Groove",
    "Lync",
    "OneDrive",
    "OneNote",
    "Outlook",
    "PowerPoint",
    "Publisher",
    "Teams",
    "Word"
)

function New-WinPilotOfficeXml {
    <#
    .SYNOPSIS
        Compiles a schema-validated Office Deployment Tool (ODT) configuration XML.
    .PARAMETER ProductId
        Office product ID (e.g. O365ProPlusRetail, ProPlus2021Volume).
    .PARAMETER AdditionalProductIds
        Optional additional products to include in the same deployment (e.g. Visio, Project).
    .PARAMETER Architecture
        Target architecture: '64' (or 'x64') or '32' (or 'x86'). Defaults to '64'.
    .PARAMETER Channel
        Update channel: Current, MonthlyEnterprise, SemiAnnual, PerpetualVL2021, PerpetualVL2024.
    .PARAMETER LanguageId
        Language tag: MatchOS, en-us, or other BCP 47 language code. Defaults to 'MatchOS'.
    .PARAMETER ExcludeApps
        Array of application IDs to exclude from installation (e.g. Access, Teams, OneDrive).
    .PARAMETER SharedComputerLicensing
        Enable Shared Computer Licensing for multi-user/VDI environments.
    .PARAMETER DisplayLevel
        Installation UI visibility: 'Full' or 'None'. Defaults to 'Full'.
    .PARAMETER AcceptEula
        Automatically accept the Microsoft Software License Terms. Defaults to $true.
    .PARAMETER OutputPath
        Optional file path to write the compiled XML configuration.
    .OUTPUTS
        [string] Compiled XML string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ProductId,

        [Parameter(Mandatory = $false)]
        [string[]]$AdditionalProductIds = @(),

        [Parameter(Mandatory = $false)]
        [ValidateSet("64", "32", "x64", "x86")]
        [string]$Architecture = "64",

        [Parameter(Mandatory = $false)]
        [string]$Channel = "Current",

        [Parameter(Mandatory = $false)]
        [string]$LanguageId = "MatchOS",

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeApps = @(),

        [Parameter(Mandatory = $false)]
        [switch]$SharedComputerLicensing,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Full", "None")]
        [string]$DisplayLevel = "Full",

        [Parameter(Mandatory = $false)]
        [bool]$AcceptEula = $true,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    # Normalize architecture string to '64' or '32'
    $archVal = if ($Architecture -in @("64", "x64")) { "64" } else { "32" }

    # Validate primary product ID
    if ($ProductId -notin $script:SupportedProducts) {
        Write-WinPilotLog -Level "WARN" -Component "XmlBuilder" -Message "Custom or unrecognized ProductId specified: $ProductId"
    }

    # Auto-adjust channel for LTSC volume products if default 'Current' was passed
    if ($ProductId -match "2021Volume" -and $Channel -eq "Current") {
        $Channel = "PerpetualVL2021"
    }
    elseif ($ProductId -match "2024Volume" -and $Channel -eq "Current") {
        $Channel = "PerpetualVL2024"
    }

    $allProducts = New-Object System.Collections.Generic.List[string]
    $allProducts.Add($ProductId)
    foreach ($ap in $AdditionalProductIds) {
        if (-not [string]::IsNullOrEmpty($ap) -and $ap -notin $allProducts) {
            $allProducts.Add($ap)
        }
    }

    Write-WinPilotLog -Level "INFO" -Component "XmlBuilder" -Message "Compiling ODT configuration XML for products: $($allProducts -join ', ') ($archVal-bit, $Channel)"

    $stringWriter = New-Object System.IO.StringWriter
    $xmlSettings = New-Object System.Xml.XmlWriterSettings
    $xmlSettings.Indent = $true
    $xmlSettings.OmitXmlDeclaration = $true
    $xmlSettings.Encoding = [System.Text.Encoding]::UTF8

    $writer = [System.Xml.XmlWriter]::Create($stringWriter, $xmlSettings)

    try {
        $writer.WriteStartElement("Configuration")

        # <Add OfficeClientEdition="..." Channel="...">
        $writer.WriteStartElement("Add")
        $writer.WriteAttributeString("OfficeClientEdition", $archVal)
        $writer.WriteAttributeString("Channel", $Channel)

        foreach ($prod in $allProducts) {
            # <Product ID="...">
            $writer.WriteStartElement("Product")
            $writer.WriteAttributeString("ID", $prod)

            # <Language ID="..." />
            $writer.WriteStartElement("Language")
            $writer.WriteAttributeString("ID", $LanguageId)
            $writer.WriteEndElement() # Language

            # <ExcludeApp ID="..." />
            foreach ($app in $ExcludeApps) {
                if (-not [string]::IsNullOrEmpty($app)) {
                    $writer.WriteStartElement("ExcludeApp")
                    $writer.WriteAttributeString("ID", $app.Trim())
                    $writer.WriteEndElement() # ExcludeApp
                }
            }

            $writer.WriteEndElement() # Product
        }

        $writer.WriteEndElement() # Add

        # <Display Level="..." AcceptEULA="..." />
        $writer.WriteStartElement("Display")
        $writer.WriteAttributeString("Level", $DisplayLevel)
        $writer.WriteAttributeString("AcceptEULA", $(if ($AcceptEula) { "TRUE" } else { "FALSE" }))
        $writer.WriteEndElement() # Display

        # <Property Name="SharedComputerLicensing" Value="1" />
        if ($SharedComputerLicensing) {
            $writer.WriteStartElement("Property")
            $writer.WriteAttributeString("Name", "SharedComputerLicensing")
            $writer.WriteAttributeString("Value", "1")
            $writer.WriteEndElement() # Property
        }

        # <Updates Enabled="TRUE" />
        $writer.WriteStartElement("Updates")
        $writer.WriteAttributeString("Enabled", "TRUE")
        $writer.WriteEndElement() # Updates

        # <RemoveMSI /> to automatically clean up legacy MSI installations
        $writer.WriteStartElement("RemoveMSI")
        $writer.WriteEndElement() # RemoveMSI

        $writer.WriteEndElement() # Configuration
        $writer.Flush()
    }
    finally {
        $writer.Close()
    }

    $xmlContent = $stringWriter.ToString()

    if (-not [string]::IsNullOrEmpty($OutputPath)) {
        $parentDir = Split-Path -Path $OutputPath -Parent
        if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -Path $parentDir)) {
            [void](New-Item -ItemType Directory -Path $parentDir -Force)
        }
        [System.IO.File]::WriteAllText($OutputPath, $xmlContent, [System.Text.Encoding]::UTF8)
        Write-WinPilotLog -Level "INFO" -Component "XmlBuilder" -Message "ODT XML configuration saved to $OutputPath"
    }

    return $xmlContent
}
