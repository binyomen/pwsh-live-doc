function WriteHtmlFile {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [String] $FilePath,
        [Parameter(Mandatory)]
        [String] $Html
    )

    [String] $webrootPath = "$PSScriptRoot\..\webroot"
    [String] $filePath = "$webrootPath\$FilePath"

    New-Item $filePath -Force > $null
    Set-Content $filePath $Html
}

[PSCustomObject] $script:options = $null

function GenerateSite {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $PageFilter,
        [Parameter(Mandatory)]
        [PSCustomObject] $Options
    )

    $script:options = $Options

    [String] $projectRoot = "$PSScriptRoot\.."

    [String] $webrootPath = "$projectRoot\webroot"
    if (-not (Test-Path $webrootPath)) {
        mkdir $webrootPath > $null
    }
    Remove-Item "$webrootPath\*" -Recurse -Force -ErrorAction "SilentlyContinue"

    [PSCustomObject[]] $pages = Get-ChildItem "$projectRoot\example-pages\*.psm1" -Exclude "category.psm1" -Recurse |`
        ForEach-Object { NewPage $_ }
    [PSCustomObject[]] $filteredPages = $pages | Where-Object { Invoke-Command $PageFilter -Args $pages, $_ }

    # Build the page outlines.
    [Dictionary[String, Tuple[String, Dictionary[String, String]]]] $script:outline = [Dictionary[String, Tuple[String, Dictionary[String, String]]]]::new()
    [Boolean] $script:buildingOutline = $true
    $filteredPages | `
        ForEach-Object { $_.AddToOutline() }
    $script:buildingOutline = $false

    # Write out the example page files.
    $filteredPages | `
        ForEach-Object { WriteHtmlFile $_.GetLinkPath() $_.GetHtml($filteredPages) }

    # Write out the home page file.
    [String] $homePageHtml = OutputHomePage $filteredPages
    WriteHtmlFile 'index.html' $homePageHtml

    # Copy static assets to the webroot.
    Copy-Item "$projectRoot\static\*" $webrootPath -Recurse
}
