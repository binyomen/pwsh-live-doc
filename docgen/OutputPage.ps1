function OutputPage {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [FileInfo] $PageModuleFile
    )

    Import-Module $PageModuleFile -Force

    [String] $title = GetTitle
    Write-Host
    Write-Host "============$($PageModuleFile.Name)============"
    Write-Host "Generating page for '$title'"
    [String] $pageHtml = (RunPage) -join "`n"
    Write-Host "==========================================="

    return "<section><h2>$title</h2>$pageHtml</section>"
}
