<#
.SYNOPSIS
    WinPilot Terminal User Interface (TUI) and ANSI Rendering Engine.

.DESCRIPTION
    Provides formatted terminal output, box drawing, status banners,
    and responsive console menus with ANSI color styling and fallback support.
#>

$script:Ansi = @{
    Reset      = "$([char]27)[0m"
    Bold       = "$([char]27)[1m"
    Dim        = "$([char]27)[2m"
    Cyan       = "$([char]27)[36m"
    BrightCyan = "$([char]27)[96m"
    Green      = "$([char]27)[32m"
    BrightGreen= "$([char]27)[92m"
    Yellow     = "$([char]27)[33m"
    BrightYellow= "$([char]27)[93m"
    Red        = "$([char]27)[31m"
    BrightRed  = "$([char]27)[91m"
    White      = "$([char]27)[37m"
    BrightWhite= "$([char]27)[97m"
    Gray       = "$([char]27)[90m"
    BgBlue     = "$([char]27)[44m"
    BgGray     = "$([char]27)[100m"
}

function Get-WinPilotAnsiColor {
    <#
    .SYNOPSIS
        Returns an ANSI color sequence or empty string if ANSI is disabled.
    .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ColorName
    )

    if ($script:Ansi.ContainsKey($ColorName)) {
        return $script:Ansi[$ColorName]
    }
    return ""
}

function Clear-WinPilotScreen {
    <#
    .SYNOPSIS
        Clears the console screen and repositions cursor to top-left.
    #>
    [CmdletBinding()]
    param()

    [Console]::Clear()
}

function Show-WinPilotHeader {
    <#
    .SYNOPSIS
        Renders the application header banner with environment badges.
    .PARAMETER Subtitle
        Optional subtitle or current section title.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Subtitle = "Independent Windows & Office Management Toolkit"
    )

    $hostInfo = Get-WinPilotHost
    $adminBadge = if ($hostInfo.IsAdministrator) {
        "$($script:Ansi.BrightGreen)[ADMIN: ELEVATED]$($script:Ansi.Reset)"
    } else {
        "$($script:Ansi.BrightYellow)[USER: LIMITED]$($script:Ansi.Reset)"
    }

    $psBadge = "$($script:Ansi.BrightCyan)PS $($hostInfo.PowerShellVersion.Major).$($hostInfo.PowerShellVersion.Minor)$($script:Ansi.Reset)"
    $osBadge = "$($script:Ansi.Gray)WinBuild $($hostInfo.OSBuild) ($($hostInfo.Architecture))$($script:Ansi.Reset)"

    Write-Host ""
    Write-Host "$($script:Ansi.BrightCyan)╔════════════════════════════════════════════════════════════════════════════╗$($script:Ansi.Reset)"
    Write-Host "$($script:Ansi.BrightCyan)║$($script:Ansi.Reset)  $($script:Ansi.Bold)$($script:Ansi.BrightWhite)WINPILOT$($script:Ansi.Reset) - Modern Windows & Office Management Architecture         $($script:Ansi.BrightCyan)║$($script:Ansi.Reset)"
    $subPadLength = [Math]::Max(0, 74 - $Subtitle.Length)
    $subPad = " " * $subPadLength
    Write-Host ("$($script:Ansi.BrightCyan)║$($script:Ansi.Reset)  $($script:Ansi.Gray)$Subtitle$($script:Ansi.Reset)$subPad$($script:Ansi.BrightCyan)║$($script:Ansi.Reset)")
    Write-Host "$($script:Ansi.BrightCyan)╠════════════════════════════════════════════════════════════════════════════╣$($script:Ansi.Reset)"
    $statusLine = "  Status: $adminBadge | $psBadge | $osBadge"
    Write-Host $statusLine
    Write-Host "$($script:Ansi.BrightCyan)╚════════════════════════════════════════════════════════════════════════════╝$($script:Ansi.Reset)"
    Write-Host ""
}

function Show-WinPilotBanner {
    <#
    .SYNOPSIS
        Displays a styled notice or alert banner.
    .PARAMETER Message
        Text message to display.
    .PARAMETER Type
        Banner type: Info, Success, Warning, Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Success" { $script:Ansi.BrightGreen }
        "Warning" { $script:Ansi.BrightYellow }
        "Error"   { $script:Ansi.BrightRed }
        Default   { $script:Ansi.BrightCyan }
    }

    $tag = "[$($Type.ToUpper())]"
    Write-Host "  $color$tag$($script:Ansi.Reset) $Message"
}

function Format-WinPilotBox {
    <#
    .SYNOPSIS
        Wraps content inside a framed double-line box.
    .PARAMETER Title
        Header title for the box.
    .PARAMETER Lines
        Array of strings to display within the box.
    .PARAMETER Width
        Width in characters (default: 76).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "",

        [Parameter(Mandatory = $true)]
        [string[]]$Lines,

        [Parameter(Mandatory = $false)]
        [int]$Width = 76
    )

    $c = $script:Ansi.BrightCyan
    $r = $script:Ansi.Reset

    # Top border with optional title
    if ([string]::IsNullOrEmpty($Title)) {
        Write-Host "  $c╔$([string]::new([char]0x2550, $Width - 2))╗$r"
    }
    else {
        $titleText = " $Title "
        $remain = $Width - 4 - $titleText.Length
        if ($remain -lt 2) { $remain = 2 }
        $left = [string]::new([char]0x2550, 2)
        $right = [string]::new([char]0x2550, $remain)
        Write-Host "  $c╔$left$($script:Ansi.Bold)$($script:Ansi.BrightWhite)$titleText$r$c$right╗$r"
    }

    # Inner lines
    foreach ($line in $Lines) {
        # Strip ANSI codes for length measurement
        $plain = $line -replace "\x1B\[[0-9;]*[a-zA-Z]", ""
        $padLength = $Width - 4 - $plain.Length
        if ($padLength -lt 0) { $padLength = 0 }
        $pad = " " * $padLength
        Write-Host "  $c║$r  $line$pad$c║$r"
    }

    # Bottom border
    Write-Host "  $c╚$([string]::new([char]0x2550, $Width - 2))╝$r"
}
