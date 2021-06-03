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

#region Page

function NewPage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [FileInfo] $ModuleFile
    )

    [PSCustomObject] $module = New-Module { Import-Module $args[0] -Force } -ArgumentList $ModuleFile -AsCustomObject

    [FileInfo] $categoryModuleFile = "$($ModuleFile.Directory)\category.psm1"
    [PSCustomObject] $categoryModule = New-Module { Import-Module $args[0] -Force } -ArgumentList $categoryModuleFile -AsCustomObject

    return [PSCustomObject]@{
        PSTypeName = 'Page'
        ModuleFileName = $ModuleFile.Name
        Module = $module
        CategoryModule = $categoryModule
    }
}

AddScriptMethod Page GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return $this.Module.GetTitle()
}

AddScriptMethod Page GetCategoryTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return $this.CategoryModule.GetTitle()
}

AddScriptMethod Page GetLinkPath {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [String] $pageSlug = TitleToUrlPathSegment $this.GetTitle()
    return "/$pageSlug.html"
}

AddScriptMethod Page AddToOutline {
    [CmdletBinding()]
    [OutputType([Void])]
    param()

    [Dictionary[String, String]] $script:currentOutline = [Dictionary[String, String]]::new()

    $this.Module.RunPage() > $null

    $script:outline[$this.GetTitle()] = [Tuple]::Create($this.GetLinkPath(), $script:currentOutline)
}

AddScriptMethod Page GetHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('Page')]
        [PSCustomObject[]] $AllPages
    )

    [Byte] $script:sectionLevel = 0
    return OutputExamplePage $this $this.ModuleFileName $this.Module $AllPages
}

#endregion

#region Redirect

function GetRedirects {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [String] $RedirectsFilePath
    )

    return Get-Content $RedirectsFilePath | ForEach-Object {
        [String] $line = $_
        [String[]] $tokens = $line.Split()
        return NewRedirect $tokens[0] $tokens[-1]
    }
}

function NewRedirect {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [String] $FromUrl,

        [Parameter(Mandatory)]
        [String] $ToUrl
    )

    return [PSCustomObject]@{
        PSTypeName = 'Redirect'
        FromUrl = "$FromUrl.html"
        ToUrl = "$ToUrl.html"
    }
}

AddScriptMethod Redirect GetHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return @"
    <!DOCTYPE html>
    <html lang="en-US">
        <head>
            <meta charset="UTF-8">
            <meta http-equiv="refresh" content="0; url='$($this.ToUrl)'" />
        </head>
        <body>
            <p>Redirecting to <a href="$($this.ToUrl)">$($this.ToUrl)</a>...</p>
        </body>
    </html>
"@
}

#endregion

function GetVersionsTestedHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [SemanticVersion[]] $versionsTested = GetPowerShellExesToTest | ForEach-Object { $_.Version } | Sort-Object
    return ($versionsTested | ForEach-Object { "<span class=`"tested-version`">$_</span>" }) -join ", "
}

function BuildSidebarHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [PSTypeName('Page')]
        [PSCustomObject] $ContainingPage,

        [Parameter(Mandatory)]
        [PSTypeName('Page')]
        [PSCustomObject[]] $Pages
    )

    [Dictionary[String, [PSCustomObject[]]]] $categoryToPagesMap = [Dictionary[String, [PSCustomObject[]]]]::new()
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
            [PSCustomObject] $page = $_

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
        [PSTypeName('Page')]
        [PSCustomObject] $ContainingPage,

        [Parameter(Mandatory)]
        [String] $Title,

        [Parameter(Mandatory)]
        [String] $ContentHtml,

        [Parameter(Mandatory)]
        [PSTypeName('Page')]
        [PSCustomObject[]] $Pages,

        [Switch] $IncludeHighlightDeps
    )

    [String] $sidebarHtml = BuildSidebarHtml $ContainingPage $Pages

    [String] $html = @"
    <!DOCTYPE html>
    <html lang="en-US">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>$Title</title>
            <link rel="stylesheet" type="text/css" href="/css/style.css">
            <script src="/js/script.js" type="module"></script>
            $(if ($IncludeHighlightDeps) {
                '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.0/styles/magula.min.css">
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
                    <article>
                        $ContentHtml
                    </article>
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
