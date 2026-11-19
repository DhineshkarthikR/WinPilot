#
# Module manifest for module 'WinPilot'
# Generated for Milestone 1 - Core Framework & Host Engine
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'WinPilot.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'd3e91d57-3f30-4e4b-9728-6e792e3a1f82'

    # Author of this module
    Author = 'WinPilot Project Contributors'

    # Company or vendor of this module
    CompanyName = 'WinPilot Open Source'

    # Copyright statement for this module
    Copyright = '(c) WinPilot. Licensed under the MIT License.'

    # Description of the functionality provided by this module
    Description = 'Independent Windows and Office Management Toolkit inspired by terminal-driven administration architectures. Purely legitimate deployment, diagnostics, and system maintenance.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Start-WinPilot',
        'Get-WinPilotHost',
        'Test-WinPilotAdmin',
        'Initialize-WinPilotConsole',
        'Initialize-WinPilotLogger',
        'Get-WinPilotLogPath',
        'Write-WinPilotLog',
        'Get-WinPilotAnsiColor',
        'Clear-WinPilotScreen',
        'Show-WinPilotHeader',
        'Show-WinPilotBanner',
        'Format-WinPilotBox',
        'Read-WinPilotKey',
        'Read-WinPilotChoice',
        'Confirm-WinPilotAction',
        'Get-WinPilotFileHash',
        'Test-WinPilotFileIntegrity',
        'Test-WinPilotManifest',
        'Get-WinPilotSignature',
        'Test-WinPilotAuthenticode',
        'Invoke-WinPilotSecureStage'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            Tags = @('Windows', 'Office', 'ODT', 'Management', 'Diagnostics', 'TUI')
            ProjectUri = 'https://github.com/winpilot/winpilot'
            LicenseUri = 'https://github.com/winpilot/winpilot/blob/main/LICENSE'
        }
    }
}
