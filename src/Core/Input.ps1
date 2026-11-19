<#
.SYNOPSIS
    WinPilot Keyboard Navigation and Confirmation Guardrail Module.

.DESCRIPTION
    Provides single-keypress interactive menu selection, input validation,
    and safety guardrails requiring explicit user confirmation before executing
    system-changing or destructive operations.
#>

function Read-WinPilotKey {
    <#
    .SYNOPSIS
        Reads a single keypress from the console without echoing to screen.
    .OUTPUTS
        [System.ConsoleKeyInfo]
    #>
    [CmdletBinding()]
    param()

    try {
        if ([System.Environment]::UserInteractive) {
            return [Console]::ReadKey($true)
        }
    }
    catch {
        # Fallback for redirected streams or specialized test hosts
    }

    $raw = Read-Host
    if (-not [string]::IsNullOrEmpty($raw)) {
        return [PSCustomObject]@{
            KeyChar = $raw[0]
            Key     = [ConsoleKey]::None
        }
    }
    return [PSCustomObject]@{
        KeyChar = [char]0
        Key     = [ConsoleKey]::None
    }
}

function Read-WinPilotChoice {
    <#
    .SYNOPSIS
        Waits for a single valid menu selection key.
    .PARAMETER ValidKeys
        Array of valid character choices (e.g. '1','2','3','0','Q').
    .PARAMETER Prompt
        Custom prompt message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [char[]]$ValidKeys,

        [Parameter(Mandatory = $false)]
        [string]$Prompt = "  Enter choice: "
    )

    Write-Host -NoNewline $Prompt

    while ($true) {
        $keyInfo = Read-WinPilotKey
        $char = [char]::ToUpperInvariant($keyInfo.KeyChar)

        foreach ($vk in $ValidKeys) {
            if ([char]::ToUpperInvariant($vk) -eq $char) {
                Write-Host "$char" -ForegroundColor Green
                return $char
            }
        }

        # Handle ESC or Q as graceful back/exit if allowed
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            Write-Host "[ESC]" -ForegroundColor Yellow
            return [char]'0'
        }
    }
}

function Confirm-WinPilotAction {
    <#
    .SYNOPSIS
        Displays a safety confirmation dialog before executing system operations.
    .DESCRIPTION
        Guarantees that no system-changing or destructive action runs without
        explicit user consent. Defaults strictly to NO.
    .PARAMETER ActionName
        Human-readable description of the action.
    .PARAMETER RiskLevel
        Risk level: Low, Moderate, High, Critical.
    .PARAMETER RequiresTypedConfirmation
        If true, the user must explicitly type 'YES' or 'CONFIRM' rather than pressing 'Y'.
    .OUTPUTS
        [bool] True if user explicitly confirms, False otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Low", "Moderate", "High", "Critical")]
        [string]$RiskLevel = "Moderate",

        [Parameter(Mandatory = $false)]
        [switch]$RequiresTypedConfirmation
    )

    $riskColor = switch ($RiskLevel) {
        "Low"      { [ConsoleColor]::Cyan }
        "Moderate" { [ConsoleColor]::Yellow }
        "High"     { [ConsoleColor]::Red }
        "Critical" { [ConsoleColor]::DarkRed }
        Default    { [ConsoleColor]::Yellow }
    }

    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor $riskColor
    Write-Host "  CONFIRMATION REQUIRED - RISK LEVEL: $($RiskLevel.ToUpper())" -ForegroundColor $riskColor
    Write-Host "  ================================================================" -ForegroundColor $riskColor
    Write-Host "  Action: $ActionName" -ForegroundColor White
    Write-Host "  Default selection is [NO]. No changes will occur unless confirmed." -ForegroundColor Gray
    Write-Host ""

    if ($RequiresTypedConfirmation -or $RiskLevel -in @("High", "Critical")) {
        Write-Host -NoNewline "  Type 'YES' to proceed, or press Enter to cancel: " -ForegroundColor Yellow
        $response = Read-Host
        $isConfirmed = ($response -eq "YES")
    }
    else {
        Write-Host -NoNewline "  Proceed with this operation? [y/N]: " -ForegroundColor Yellow
        $key = Read-WinPilotKey
        $char = [char]::ToUpperInvariant($key.KeyChar)
        Write-Host "$char"
        $isConfirmed = ($char -eq 'Y')
    }

    if ($isConfirmed) {
        Write-WinPilotLog -Level "AUDIT" -Component "SafetyGuard" -Message "User confirmed action: $ActionName ($RiskLevel)"
        Write-Host "  [CONFIRMED] Executing action..." -ForegroundColor Green
        return $true
    }
    else {
        Write-WinPilotLog -Level "AUDIT" -Component "SafetyGuard" -Message "User cancelled action: $ActionName"
        Write-Host "  [CANCELLED] Operation aborted by user. No changes made." -ForegroundColor Yellow
        return $false
    }
}
