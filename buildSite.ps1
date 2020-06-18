[CmdletBinding()]
[OutputType([Void])]
param(
    [Parameter(ParameterSetName="Filter")]
    [ScriptBlock] $PageFilter = {
        param([Page[]] $AllPages, [Page] $PageToCheck)
        return $true
    },

    [Parameter(Mandatory, ParameterSetName="PageName")]
    [String] $PageName,

    [Switch] $TestOnlyMajorVersions
)

Push-Location $PSScriptRoot
try {
    if ($PSCmdlet.ParameterSetName -eq "PageName") {
        $PageFilter = [ScriptBlock]::Create(
            "param([Page[]] `$AllPages, [Page] `$PageToCheck)
            return `$PageToCheck.GetTitle() -like `"$PageName`""
        )
    }

    [PSCustomObject] $options = [PSCustomObject] @{
        TestOnlyMajorVersions = $TestOnlyMajorVersions.ToBool()
    }

    # Building needs to run in its own powershell session because otherwise
    # classes in modules like docgen get cached and can't be changed during
    # development. Import-Module -Force doesn't work with classes :(
    pwsh -Command {
        param(
            [Parameter(Mandatory)]
            [String] $PageFilter,
            [Parameter(Mandatory)]
            [String] $OptionsString
        )

        Set-StrictMode -Version Latest
        $script:ErrorActionPreference = "Stop"

        Import-Module .\docgen -Force

        GenerateSite -PageFilter ([ScriptBlock]::Create($PageFilter)) -Options (ConvertFrom-Json $OptionsString)
    } -Args $PageFilter, (ConvertTo-Json $options)
} finally {
    Pop-Location
}
