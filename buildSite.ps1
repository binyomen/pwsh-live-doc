using namespace System.IO
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$script:ErrorActionPreference = "Stop"

Import-Module $PSScriptRoot\docgen -Force

[FileInfo[]] $pageModules = Get-ChildItem $PSScriptRoot "example-pages\*.psm1"
[String[]] $scriptHtml = $pageModules | ForEach-Object { OutputPage $_ }

[SemanticVersion[]] $versionsTested = GetPowerShellExesToTest | ForEach-Object { GetExeVersion $_ } | Sort-Object
[String] $versionsTestedHtml = ($versionsTested | ForEach-Object { "<span class=`"tested-version`">$_</span>" }) -join ", "

[String] $htmlPrefix = @"
<!DOCTYPE html>
<html lang="en-US">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>PowerShell live documentation</title>
        <link rel="stylesheet" type="text/css" href="style.css">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.0/styles/default.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.3/highlight.min.js"></script>
        <script charset="UTF-8" src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.3/languages/powershell.min.js"></script>
        <script>hljs.initHighlightingOnLoad();</script>
    </head>
    <body>
        <div id="content">
            <header>
                <h1>PowerShell live documentation</h1>
                <p id="versions-tested-line">Versions tested: $versionsTestedHtml</p>
            </header>
            <main>
"@

[String] $htmlSuffix = @'
            </main>
        </div>
    </body>
</html>
'@

[String] $html = "$htmlPrefix$scriptHtml$htmlSuffix"

[String] $webrootPath = "$PSScriptRoot\webroot"
Remove-Item $webrootPath -Recurse -Force -ErrorAction "SilentlyContinue"
mkdir $webrootPath > $null

Set-Content $webrootPath\index.html $html
Copy-Item $PSScriptRoot\style.css $webrootPath
