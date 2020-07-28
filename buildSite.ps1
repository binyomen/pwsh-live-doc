[CmdletBinding()]
[OutputType([Void])]
param(
    [Parameter(ParameterSetName='Filter')]
    [ScriptBlock] $PageFilter = {
        param(
            [Parameter(Mandatory)]
            [PSTypeName('Page')]
            [PSCustomObject[]] $AllPages,

            [Parameter(Mandatory)]
            [PSTypeName('Page')]
            [PSCustomObject] $PageToCheck
        )
        return $true
    },

    [Parameter(Mandatory, ParameterSetName='PageNames')]
    [String[]] $PageNames,

    [Switch] $TestOnlyMajorVersions
)

if ($PSCmdlet.ParameterSetName -eq 'PageNames') {
    $PageFilter = {
        param(
            [Parameter(Mandatory)]
            [PSTypeName('Page')]
            [PSCustomObject[]] $AllPages,

            [Parameter(Mandatory)]
            [PSTypeName('Page')]
            [PSCustomObject] $PageToCheck
        )

        [String] $title = $PageToCheck.GetTitle()
        $PageNames | ForEach-Object `
            { [Boolean] $b = $false } `
            { $b = $b -or ($title -like $_) } `
            { $b }
    }
}

[PSCustomObject] $options = [PSCustomObject]@{
    TestOnlyMajorVersions = $TestOnlyMajorVersions.ToBool()
}

Import-Module $PSScriptRoot\docgen -Force
GenerateSite -PageFilter $PageFilter -Options $options
