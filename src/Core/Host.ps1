<#
.SYNOPSIS
    WinPilot Host and Environment Detection Module.

.DESCRIPTION
    Provides functions to inspect the host execution environment, verify
    PowerShell 5.1/7+ runtime versions, detect administrative privileges,
    and configure console compatibility.
#>

function Get-WinPilotHost {
    <#
    .SYNOPSIS
        Retrieves detailed information about the current Windows and PowerShell environment.
    .OUTPUTS
        [PSCustomObject] containing system and runtime properties.
    #>
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $osVersion = [System.Environment]::OSVersion.Version
    $isWin11 = $osVersion.Major -ge 10 -and $osVersion.Build -ge 22000

    $isWindowsTerminal = [bool]$env:WT_SESSION
    $isAnsiSupported = $isWindowsTerminal -or ($osVersion.Major -ge 10 -and $osVersion.Build -ge 10586)

    [PSCustomObject]@{
        PowerShellVersion  = $PSVersionTable.PSVersion
        PowerShellEdition  = $PSVersionTable.PSEdition
        IsPowerShell51     = ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1)
        IsPowerShellCore   = ($PSVersionTable.PSVersion.Major -ge 6)
        OSVersion          = $osVersion.ToString()
        OSBuild            = $osVersion.Build
        IsWindows11        = $isWin11
        IsWindows10        = (-not $isWin11 -and $osVersion.Major -ge 10)
        IsAdministrator    = $isAdmin
        IsWindowsTerminal  = $isWindowsTerminal
        IsAnsiSupported    = $isAnsiSupported
        Architecture       = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
        ComputerName       = [System.Environment]::MachineName
        CurrentUserName    = [System.Environment]::UserName
    }
}

function Test-WinPilotAdmin {
    <#
    .SYNOPSIS
        Tests if the current session has elevated administrator rights.
    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-WinPilotConsole {
    <#
    .SYNOPSIS
        Configures console output encoding and terminal buffer settings.
    #>
    [CmdletBinding()]
    param()

    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
    catch {
        # Fall back gracefully if host blocks encoding reassignment
    }

    # Enable virtual terminal processing for Windows 10/11 conhost if supported
    if ([System.Environment]::OSVersion.Version.Major -ge 10) {
        try {
            $kernel32 = Add-Type -MemberDefinition @"
                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern IntPtr GetStdHandle(int nStdHandle);

                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
"@ -Name "WinPilotConsoleHelper" -Namespace "WinPilot.Native" -PassThru -ErrorAction SilentlyContinue

            if ($kernel32) {
                $stdOut = $kernel32::GetStdHandle(-11) # STD_OUTPUT_HANDLE
                $mode = 0
                if ($kernel32::GetConsoleMode($stdOut, [ref]$mode)) {
                    # ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                    $newMode = $mode -bor 0x0004
                    [void]$kernel32::SetConsoleMode($stdOut, $newMode)
                }
            }
        }
        catch {
            # Non-critical: console will render using standard fallback colors
        }
    }
}
