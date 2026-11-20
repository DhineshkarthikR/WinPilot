<#
.SYNOPSIS
    WinPilot Microsoft Office Licensing & Subscription Diagnostics Module.

.DESCRIPTION
    Provides separate diagnostic pipelines for:
    1. Perpetual Office licenses (Office 2016, 2019, 2021, 2024 LTSC, Standard, Project, Visio)
       via CIM/WMI SoftwareLicensingProduct and OSPP interfaces.
    2. Microsoft 365 subscription diagnostics (Click-to-Run configuration, update channels,
       shared computer licensing, and local subscription token artifacts).
    Strictly read-only; no unauthorized activation or bypass mechanisms.
#>

function Get-WinPilotOfficePerpetualStatus {
    <#
    .SYNOPSIS
        Audits installed perpetual Microsoft Office licenses (Retail, Volume:MAK, Volume:GVLK/KMS).
    .OUTPUTS
        [PSCustomObject[]] or [System.Object[]]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]], [System.Object[]])]
    param()

    Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "Auditing perpetual Office licenses via CIM"

    $officeAppId = "0ff1ce15-a989-479d-af46-f275c6370663"
    $statusMap = @{
        0 = "Unlicensed"
        1 = "Licensed (Activated)"
        2 = "Initial Grace Period"
        3 = "Out-of-Tolerance Grace Period"
        4 = "Non-Genuine Grace Period"
        5 = "Notification (Unlicensed / Expired)"
        6 = "Extended Grace Period"
    }

    $results = New-Object System.Collections.Generic.List[PSCustomObject]

    try {
        $filter = "ApplicationID = '$officeAppId' and PartialProductKey IS NOT NULL"
        $products = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter $filter -ErrorAction SilentlyContinue

        foreach ($p in $products) {
            # Filter OUT pure subscription licenses (handled by Get-WinPilotOfficeSubscriptionStatus)
            $isSubscription = ($p.Description -match "TIMEBASED_SUB|SUBSCRIPTION" -or $p.Name -match "O365|Subscription")
            if ($isSubscription) {
                continue
            }

            $channel = "Unspecified / Ambiguous Channel"
            if ($p.Description -match "RETAIL") { $channel = "Retail" }
            elseif ($p.Description -match "VOLUME_KMSCLIENT|VOLUME:GVLK") { $channel = "Volume: GVLK (KMS Client)" }
            elseif ($p.Description -match "VOLUME_MAK") { $channel = "Volume: MAK" }
            elseif ($p.Description -match "VOLUME") { $channel = "Volume Channel" }

            $statusCode = [int]$p.LicenseStatus
            $statusText = if ($statusMap.ContainsKey($statusCode)) { $statusMap[$statusCode] } else { "Unknown ($statusCode)" }

            $results.Add([PSCustomObject]@{
                ProductName       = $p.Name
                Description       = $p.Description
                LicenseStatus     = $statusCode
                LicenseStatusText = $statusText
                LicensingChannel  = $channel
                PartialProductKey = $p.PartialProductKey
                GracePeriodRemaining = $p.GracePeriodRemaining
            })
        }
    }
    catch {
        Write-WinPilotLog -Level "WARN" -Component "Diagnostics" -Message "Office perpetual CIM query error: $($_.Exception.Message)"
    }

    # Verify if ospp.vbs exists on filesystem
    $osppPaths = @(
        "$env:ProgramFiles\Microsoft Office\Office16\OSPP.VBS",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS",
        "$env:ProgramFiles\Microsoft Office\Office15\OSPP.VBS",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office15\OSPP.VBS"
    )
    $hasOsppScript = $false
    foreach ($path in $osppPaths) {
        if (Test-Path -Path $path) {
            $hasOsppScript = $true
            break
        }
    }

    Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "Perpetual licenses discovered: $($results.Count) (OSPP tool detected: $hasOsppScript)"

    return ,$results.ToArray()
}

function Get-WinPilotOfficeSubscriptionStatus {
    <#
    .SYNOPSIS
        Audits Microsoft 365 Click-to-Run (C2R) subscription licensing, update channels, and tokens.
    .OUTPUTS
        [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-WinPilotLog -Level "INFO" -Component "Diagnostics" -Message "Auditing Microsoft 365 subscription configuration"

    $c2rRegPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    $isC2rInstalled = Test-Path -Path $c2rRegPath

    $productReleaseIds = "None"
    $version = "Not Installed"
    $channelUrl = ""
    $channelFriendly = "N/A"
    $platform = "N/A"
    $sharedLicensing = $false
    $tokenCount = 0

    if ($isC2rInstalled) {
        $props = Get-ItemProperty -Path $c2rRegPath -ErrorAction SilentlyContinue
        if ($props) {
            if (-not [string]::IsNullOrEmpty($props.ProductReleaseIds)) {
                $productReleaseIds = $props.ProductReleaseIds
            }
            if (-not [string]::IsNullOrEmpty($props.VersionToReport)) {
                $version = $props.VersionToReport
            }
            if (-not [string]::IsNullOrEmpty($props.Platform)) {
                $platform = $props.Platform
            }
            if (-not [string]::IsNullOrEmpty($props.UpdateChannel)) {
                $channelUrl = $props.UpdateChannel

                $channelMap = @{
                    "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60" = "Current Channel"
                    "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6" = "Monthly Enterprise Channel"
                    "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114" = "Semi-Annual Enterprise Channel"
                    "http://officecdn.microsoft.com/pr/5440fd1f-7324-4fc0-8fdc-3c4f78611616" = "Beta Channel (Insider Fast)"
                    "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf" = "Current Channel (Preview)"
                }

                if ($channelMap.ContainsKey($channelUrl.ToLowerInvariant())) {
                    $channelFriendly = $channelMap[$channelUrl.ToLowerInvariant()]
                }
                elseif ($channelMap.ContainsKey($channelUrl)) {
                    $channelFriendly = $channelMap[$channelUrl]
                }
                else {
                    $channelFriendly = "Custom / CDN URL"
                }
            }

            # Check Shared Computer Licensing (SCL)
            if ($props.SharedComputerLicensing -eq 1 -or $props.SharedComputerLicensing -eq "1") {
                $sharedLicensing = $true
            }
        }

        # Check policy override for Shared Computer Licensing
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing"
        if (Test-Path $policyPath) {
            $policyVal = (Get-ItemProperty -Path $policyPath -Name "SharedComputerLicensing" -ErrorAction SilentlyContinue).SharedComputerLicensing
            if ($policyVal -eq 1) {
                $sharedLicensing = $true
            }
        }

        # Inspect local user subscription token directory
        $tokenDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, "Microsoft", "Office", "16.0", "Licensing")
        if (Test-Path -Path $tokenDir) {
            $tokens = Get-ChildItem -Path $tokenDir -Filter "*.auth" -File -ErrorAction SilentlyContinue
            if ($tokens) {
                $tokenCount = $tokens.Count
            }
        }
    }

    # Query any subscription licenses in CIM
    $officeAppId = "0ff1ce15-a989-479d-af46-f275c6370663"
    $cimSubscriptionName = "None"
    $cimSubscriptionStatus = "None"
    try {
        $filter = "ApplicationID = '$officeAppId' and PartialProductKey IS NOT NULL"
        $cimSubs = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter $filter -ErrorAction SilentlyContinue |
            Where-Object { $_.Description -match "TIMEBASED_SUB|SUBSCRIPTION" -or $_.Name -match "O365|Subscription" }

        if ($cimSubs) {
            $activeSub = $cimSubs | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -First 1
            if (-not $activeSub) { $activeSub = $cimSubs | Select-Object -First 1 }

            $cimSubscriptionName = $activeSub.Name
            $cimSubscriptionStatus = if ($activeSub.LicenseStatus -eq 1) { "Licensed (Active)" } else { "Notification ($($activeSub.LicenseStatus))" }
        }
    }
    catch {
        $null = $_
    }

    # Determine verified subscription status vs cached tokens
    $verifiedSub = "Not Verified (No Active Subscription in CIM)"
    if ($cimSubscriptionStatus -eq "Licensed (Active)") {
        $verifiedSub = "Verified Active (CIM)"
    }
    elseif ($cimSubscriptionStatus -ne "None") {
        $verifiedSub = "Inactive / Notification (CIM)"
    }

    $tokenStatus = if ($tokenCount -gt 0) {
        "Cached Token Present ($tokenCount token(s) on disk - Verification required)"
    } else {
        "No Cached Tokens Found"
    }

    return [PSCustomObject]@{
        IsClickToRunInstalled       = $isC2rInstalled
        InstallationState           = if ($isC2rInstalled) { "Installed" } else { "Not Installed" }
        ProductReleaseIds           = $productReleaseIds
        Version                     = $version
        Architecture                = $platform
        UpdateChannel               = $channelFriendly
        UpdateChannelUrl            = $channelUrl
        SharedComputerLicensing     = $sharedLicensing
        SubscriptionTokenCount      = $tokenCount
        TokenStatus                 = $tokenStatus
        VerifiedSubscriptionStatus  = $verifiedSub
        CimSubscriptionName         = $cimSubscriptionName
        CimSubscriptionStatus       = $cimSubscriptionStatus
    }
}

function Show-WinPilotOfficeLicenseReport {
    <#
    .SYNOPSIS
        Displays a structured, visual TUI report comparing perpetual licenses and M365 subscriptions.
    #>
    [CmdletBinding()]
    param()

    $perpetuals = Get-WinPilotOfficePerpetualStatus
    $sub = Get-WinPilotOfficeSubscriptionStatus

    $reset = Get-WinPilotAnsiColor -ColorName "Reset"
    $cyan = Get-WinPilotAnsiColor -ColorName "BrightCyan"
    $green = Get-WinPilotAnsiColor -ColorName "BrightGreen"
    $yellow = Get-WinPilotAnsiColor -ColorName "BrightYellow"
    $white = Get-WinPilotAnsiColor -ColorName "BrightWhite"
    $gray = Get-WinPilotAnsiColor -ColorName "Gray"

    # 1. Perpetual Office Report Box
    $perpLines = New-Object System.Collections.Generic.List[string]
    $perpLines.Add(" ")
    if ($perpetuals.Count -eq 0) {
        $perpLines.Add("  $gray[No perpetual Office licenses (LTSC / Retail / MAK) detected in CIM]$reset")
    }
    else {
        foreach ($p in $perpetuals) {
            $color = if ($p.LicenseStatus -eq 1) { $green } else { $yellow }
            $perpLines.Add("  Product   : $white$($p.ProductName)$reset")
            $perpLines.Add("  Status    : $color$($p.LicenseStatusText)$reset | Channel: $cyan$($p.LicensingChannel)$reset")
            $perpLines.Add("  Key (Last): $white$($p.PartialProductKey)$reset")
            $perpLines.Add(" ")
        }
    }
    $perpLines.Add(" ")

    Format-WinPilotBox -Title "PERPETUAL OFFICE LICENSES (LTSC / RETAIL / VOLUME)" -Lines $perpLines.ToArray() -Width 76
    Write-Host ""

    # 2. Microsoft 365 Subscription Report Box
    $subStatusColor = if ($sub.IsClickToRunInstalled) { $green } else { $gray }
    $sclBadge = if ($sub.SharedComputerLicensing) { "$green[ENABLED - Multi-user]$reset" } else { "$gray[Disabled - Standard]$reset" }
    $verifColor = if ($sub.VerifiedSubscriptionStatus -like "*Active*") { $green } else { $yellow }

    $subLines = @(
        " ",
        "  C2R Installed       : $subStatusColor$($sub.InstallationState)$reset",
        "  Products Detected   : $white$($sub.ProductReleaseIds)$reset",
        "  Version & Platform  : $cyan$($sub.Version)$reset ($($sub.Architecture))",
        "  Update Channel      : $white$($sub.UpdateChannel)$reset",
        "  Shared Computer Lic : $sclBadge",
        "  Cached Tokens       : $gray$($sub.TokenStatus)$reset",
        "  Subscription State  : $verifColor$($sub.VerifiedSubscriptionStatus)$reset",
        "  CIM Subscription    : $cyan$($sub.CimSubscriptionName)$reset",
        " "
    )

    Format-WinPilotBox -Title "MICROSOFT 365 SUBSCRIPTION & C2R AUDIT" -Lines $subLines -Width 76
}
