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
        [PSCustomObject] $Options
    )

    $script:options = $Options
    try {
        [String] $projectRoot = "$PSScriptRoot\.."

        [String] $webrootPath = "$projectRoot\webroot"
        Remove-Item $webrootPath -Recurse -Force -ErrorAction "SilentlyContinue"
        mkdir $webrootPath > $null

        [Page[]] $pages = Get-ChildItem "$projectRoot\example-pages\*.psm1" -Exclude "category.psm1" -Recurse |`
            ForEach-Object { [Page]::new($_) }

        # Write out the example page files.
        $pages |`
            Where-Object { Invoke-Command $PageFilter -Args $pages, $_ } |`
            ForEach-Object { WriteHtmlFile $_.GetLinkPath() $_.GetHtml($pages) }

        # Write out the home page file.
        [String] $homePageHtml = OutputHomePage $pages
        WriteHtmlFile "index.html" $homePageHtml

        # Copy static assets to the webroot.
        Copy-Item "$projectRoot\static\*" $webrootPath -Recurse
    } finally {
        $script:options = $null
    }
}
