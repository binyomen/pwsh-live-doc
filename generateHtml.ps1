function Wrap {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String[]] $Html
    )

    return "<section>$($Html -join "`n")</section>"
}

$testScripts = Get-ChildItem $PSScriptRoot "generators\*.ps1"
$testScriptHtml = $testScripts | ForEach-Object {
    $script = $_
    Write-Host
    Write-Host "============$($script.BaseName)============"
    $result = & $script.FullName
    Write-Host "==========================================="

    return Wrap $result
}

Import-Module $PSScriptRoot\docgen -Force
$versionsTested = GetPowerShellExesToTest | ForEach-Object { GetExeVersion $_ } | Sort-Object
$versionsTestedHtml = ($versionsTested | ForEach-Object { "<span class=`"tested-version`">$_</span>" }) -join ", "

$htmlPrefix = @"
<!DOCTYPE html>
<html lang="en-US">
    <head>
        <meta charset="UTF-8" />
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

$htmlSuffix = @'
            </main>
        </div>
    </body>
</html>
'@

Write-Output "$htmlPrefix $testScriptHtml $htmlSuffix"
