<#
.SYNOPSIS
    WinPilot Windows Licensing & Activation Diagnostics Module.

.DESCRIPTION
    Queries official, Microsoft-supported Windows licensing interfaces via CIM/WMI
    (SoftwareLicensingProduct, SoftwareLicensingService) to inspect activation state,
    edition, licensing channel, grace period, and embedded UEFI OEM product keys.
    Strictly read-only; no unauthorized activation or bypass mechanisms.
#>

function Get-WinPilotWindowsLicense {
    <#
    .SYNOPSIS
        Retrieves detailed Windows licensing and activation status using supported CIM interfaces.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "Initiating Windows licensing diagnostics query"

    $winAppId = "55c92734-d682-4d71-983e-d6ec3f16059f"

    # License Status Code to Human-Readable Mapping (Official Microsoft SLP definitions)
    $statusMap = @{
        0 = "Unlicensed"
        1 = "Licensed (Activated)"
        2 = "Initial Grace Period (OOBGrace)"
        3 = "Out-of-Tolerance Grace Period"
        4 = "Non-Genuine Grace Period"
        5 = "Notification (Activation Required)"
        6 = "Extended Grace Period"
    }

    $channel = "Unknown"
    $licenseStatus = -1
    $statusText = "Unknown"
    $partialKey = "None"
    $productName = "Windows Operating System"
    $description = ""
    $graceDays = 0

    try {
        $filter = "ApplicationID = '$winAppId' and PartialProductKey IS NOT NULL"
        $products = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter $filter -ErrorAction Stop

        # Select the active or primary Windows license
        $primary = $products | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -First 1
        if (-not $primary) {
            $primary = $products | Select-Object -First 1
        }

        if ($primary) {
            $productName = $primary.Name
            $description = $primary.Description
            $licenseStatus = [int]$primary.LicenseStatus
            $partialKey = $primary.PartialProductKey

            if ($statusMap.ContainsKey($licenseStatus)) {
                $statusText = $statusMap[$licenseStatus]
            }

            # Determine licensing channel from Description
            if ($description -match "RETAIL") {
                $channel = "Retail"
            }
            elseif ($description -match "OEM:DM") {
                $channel = "OEM (Direct OEM / Digital Marker)"
            }
            elseif ($description -match "OEM:COA|OEM:SLP|OEM:NONSLP") {
                $channel = "OEM (System Builder / COA)"
            }
            elseif ($description -match "VOLUME_KMSCLIENT|VOLUME:GVLK") {
                $channel = "Volume: GVLK (KMS Client)"
            }
            elseif ($description -match "VOLUME_MAK") {
                $channel = "Volume: MAK"
            }
            elseif ($description -match "VOLUME") {
                $channel = "Volume Channel"
            }

            if ($primary.GracePeriodRemaining -gt 0) {
                $graceDays = [Math]::Round($primary.GracePeriodRemaining / 1440, 1)
            }
        }
    }
    catch {
        Write-WinPilotLog -Level "WARN" -Component "Diagnostics" -Message "SoftwareLicensingProduct query error: $($_.Exception.Message)"
    }

    # Query OEM product key from UEFI ACPI table via SoftwareLicensingService
    # Security requirement: Never display or return complete product keys.
    $oemKey = "None Detected"
    $serviceVersion = "Unknown"
    try {
        $sls = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sls) {
            $serviceVersion = $sls.Version
            if (-not [string]::IsNullOrEmpty($sls.OA3xOriginalProductKey)) {
                $rawKey = $sls.OA3xOriginalProductKey.Trim()
                # Strict masking: only expose last 5 characters
                if ($rawKey.Length -ge 5) {
                    $last5 = $rawKey.Substring($rawKey.Length - 5)
                    $oemKey = "XXXXX-XXXXX-XXXXX-XXXXX-$last5"
                }
                else {
                    $oemKey = "Masked (OEM Key Present)"
                }
            }
        }
    }
    catch {
        # Non-critical: OEM key is optional
        $null = $_
    }

    $isPermanentlyActivated = ($licenseStatus -eq 1 -and $graceDays -eq 0 -and $channel -in @("Retail", "OEM (Direct OEM / Digital Marker)", "OEM (System Builder / COA)", "Volume: MAK"))

    return [PSCustomObject]@{
        ProductName            = $productName
        Description            = $description
        LicenseStatus          = $licenseStatus
        LicenseStatusText      = $statusText
        LicensingChannel       = $channel
        PartialProductKey      = $partialKey
        OemKeyEmbedded         = $oemKey
        GracePeriodDays        = $graceDays
        IsPermanentlyActivated = $isPermanentlyActivated
        LicensingServiceVersion= $serviceVersion
    }
}

function Show-WinPilotWindowsLicenseReport {
    <#
    .SYNOPSIS
        Displays a visual TUI report of the Windows licensing diagnostics.
    #>
    [CmdletBinding()]
    param()

    $lic = Get-WinPilotWindowsLicense

    $statusColor = switch ($lic.LicenseStatus) {
        1       { Get-WinPilotAnsiColor -ColorName "BrightGreen" }
        2       { Get-WinPilotAnsiColor -ColorName "BrightYellow" }
        5       { Get-WinPilotAnsiColor -ColorName "BrightYellow" }
        Default { Get-WinPilotAnsiColor -ColorName "BrightRed" }
    }
    $reset = Get-WinPilotAnsiColor -ColorName "Reset"
    $cyan = Get-WinPilotAnsiColor -ColorName "BrightCyan"
    $white = Get-WinPilotAnsiColor -ColorName "BrightWhite"
    $gray = Get-WinPilotAnsiColor -ColorName "Gray"

    $statusBadge = "$statusColor$($lic.LicenseStatusText)$reset"
    $permBadge = if ($lic.IsPermanentlyActivated) {
        "$statusColor[Yes - Permanent]$reset"
    } else {
        "$gray[No / Subscription / KMS]$reset"
    }

    $lines = @(
        " ",
        "  Product Name      : $white$($lic.ProductName)$reset",
        "  Activation Status : $statusBadge",
        "  License Channel   : $cyan$($lic.LicensingChannel)$reset",
        "  Permanent Active  : $permBadge",
        "  Partial Key (Last): $white$($lic.PartialProductKey)$reset",
        "  UEFI Embedded Key : $gray$($lic.OemKeyEmbedded)$reset",
        "  Grace Period Remaining : $(if ($lic.GracePeriodDays -gt 0) { "$($lic.GracePeriodDays) days" } else { "N/A" })",
        "  Licensing Engine  : $($lic.LicensingServiceVersion)",
        " "
    )

    Format-WinPilotBox -Title "WINDOWS LICENSING & ACTIVATION AUDIT" -Lines $lines -Width 76
}
