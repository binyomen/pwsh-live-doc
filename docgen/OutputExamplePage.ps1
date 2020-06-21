function OutputExamplePage {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('Page')]
        [PSCustomObject] $Page,

        [Parameter(Mandatory)]
        [String] $pageModuleFileName,

        [Parameter(Mandatory)]
        [PSCustomObject] $PageModule,

        [Parameter(Mandatory)]
        [PSTypeName('Page')]
        [PSCustomObject[]] $Pages
    )

    [String] $title = $PageModule.GetTitle()
    Write-Host
    Write-Host "============$pageModuleFileName============"
    Write-Host "Generating page for '$title'"
    [String] $pageHtml = ($PageModule.RunPage()) -join "`n"
    Write-Host "==========================================="

    [String] $pageContent = "<h2>$title</h2>$pageHtml"

    return BuildPageHtml $Page $title $pageContent $Pages -IncludeHighlightDeps
}
