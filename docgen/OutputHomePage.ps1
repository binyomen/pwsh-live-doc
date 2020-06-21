function OutputHomePage {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('Page')]
        [PSCustomObject[]] $Pages
    )

    [String] $mainPageContent = OutputText @'
    PowerShell is a very complex language, with subtle nuances that can trip up
    even the most experienced programmers.

    This site aims to document these dark corners of the language by running
    real example code against all PowerShell versions and displaying the
    results. The documentation is kept up-to-date by downloading all release
    versions of PowerShell Core each time the site is generated, and running
    examples against those versions as well as against Windows PowerShell 5.1
    and 2. Users can be confident that if they were to run the examples on
    their own computers, the output would be the same.

    If you know of a PowerShell quirk which is missing from this site, please
    feel free to create an issue or open a PR at
    <https://github.com/benweedon/pwsh-live-doc/>. Please also see
    <https://github.com/nightroman/PowerShellTraps/>, which is itself an
    incredible store of PowerShell knowledge this site makes heavy use of.
'@

    [String] $html = BuildPageHtml $null "PowerShell live documentation" $mainPageContent $Pages
    return $html
}
