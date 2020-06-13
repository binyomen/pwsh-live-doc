# Needed for types in classes below.
using namespace System.IO

function TitleToUrlPathSegment {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Title
    )

    [Hashtable] $translations = @{
        '<' = 'left angle bracket'
        '>' = 'right angle bracket'
        ':' = 'colon'
        '"' = 'quotation mark'
        '/' = 'slash'
        '\\' = 'backslash'
        '|' = 'pipe'
        '?' = 'question mark'
        '*' = 'star'
        '%' = 'percent sign'
    }

    [String] $seg = $Title.ToLower()

    # Replace invalid Windows/URL characters with character names.
    foreach ($key in $translations.Keys) {
        $seg = $seg -replace "[$key]", " $($translations[$key]) "
    }

    # Collapse extra spaces.
    $seg = $seg -replace " +,", ","
    $seg = $seg -replace " +", " "
    $seg = $seg.Trim()

    # Convert spaces into hyphens.
    [String] $seg = $seg -replace " ", "-"

    return $seg
}

class Page {
    [String] hidden $ModuleFileName
    [PSCustomObject] hidden $Module
    [PSCustomObject] hidden $CategoryModule

    Page([FileInfo] $ModuleFile) {
        $this.ModuleFileName = $ModuleFile.Name
        $this.Module = New-Module { Import-Module $args[0] -Force } -ArgumentList $ModuleFile -AsCustomObject

        [FileInfo] $categoryModuleFile = "$($ModuleFile.Directory)\category.psm1"
        $this.CategoryModule = New-Module { Import-Module $args[0] -Force } -ArgumentList $categoryModuleFile -AsCustomObject
    }

    [String] GetTitle() {
        return $this.Module.GetTitle()
    }

    [String] GetCategoryTitle() {
        return $this.CategoryModule.GetTitle()
    }

    [String] GetLinkPath() {
        [String] $categorySlug = TitleToUrlPathSegment $this.GetCategoryTitle()
        [String] $pageSlug = TitleToUrlPathSegment $this.GetTitle()
        return "/$categorySlug/$pageSlug.html"
    }

    [String] GetHtml([Page[]] $AllPages) {
        return OutputExamplePage $this $this.ModuleFileName $this.Module $AllPages
    }
}


function GetVersionsTestedHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [SemanticVersion[]] $versionsTested = GetPowerShellExesToTest | ForEach-Object { $_.Item2 } | Sort-Object
    return ($versionsTested | ForEach-Object { "<span class=`"tested-version`">$_</span>" }) -join ", "
}

function BuildSidebarHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Page] $ContainingPage,
        [Parameter(Mandatory)]
        [Page[]] $Pages
    )

    [Dictionary[String, Page[]]] $categoryToPagesMap = [Dictionary[String, Page[]]]::new()
    foreach ($page in $Pages) {
        [String] $categoryTitle = $page.GetCategoryTitle()
        if (-not $categoryToPagesMap.ContainsKey($categoryTitle)) {
            $categoryToPagesMap[$categoryTitle] = @()
        }

        $categoryToPagesMap[$categoryTitle] += $page
    }

    # A null page means we're outputting HTML for the home page.
    [String] $pageCategoryTitle = $null -ne $ContainingPage ? $ContainingPage.GetCategoryTitle() : ""

    [String[]] $categoryListItems = $categoryToPagesMap.Keys | ForEach-Object {
        [String] $categoryTitle = $_

        [String[]] $pageListItems = $categoryToPagesMap[$categoryTitle] | ForEach-Object {
            [Page] $page = $_

            [String] $link = "<a href=`"$($page.GetLinkPath())`">$($page.GetTitle())</a>"
            return "<li>$link</li>"
        }

        return @"
            <li>
                <details $($categoryTitle -eq $pageCategoryTitle ? "open" : "")>
                    <summary>$categoryTitle</summary>
                    <ol>$pageListItems</ol>
                </details>
            </li>
"@
    }

    return "<ol>$categoryListItems</ol>"
}

function BuildPageHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Page] $ContainingPage,
        [Parameter(Mandatory)]
        [String] $Title,
        [Parameter(Mandatory)]
        [String] $ContentHtml,
        [Parameter(Mandatory)]
        [Page[]] $Pages,
        [Switch] $IncludeHighlightDeps
    )

    [String] $sidebarHtml = BuildSidebarHtml $ContainingPage $Pages

    [String] $html= @"
    <!DOCTYPE html>
    <html lang="en-US">
        <head>
            <meta charset="UTF-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>$Title</title>
            <link rel="stylesheet" type="text/css" href="/css/style.css">
            $(if ($IncludeHighlightDeps) {
                '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.0/styles/default.min.css">
                <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.3/highlight.min.js"></script>
                <script charset="UTF-8" src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.3/languages/powershell.min.js"></script>
                <script>hljs.initHighlightingOnLoad();</script>'
            })
        </head>
        <body>
            <div id="grid-container">
                <header>
                    <h1><a href="/">PowerShell live documentation</a></h1>
                </header>
                <main>
                    $ContentHtml
                </main>
                <aside id="versions-tested" aria-labelledby="versions-tested-heading">
                    <h2 id="versions-tested-heading">Versions tested</h2>
                    <p>$(GetVersionsTestedHtml)</p>
                </aside>
                <nav id="page-nav" aria-labelledby="page-nav-heading">
                    <h2 id="page-nav-heading">Pages</h2>
                    $sidebarHtml
                </nav>
            </div>
        </body>
    </html>
"@

    return $html
}
