$testScripts = Get-ChildItem $PSScriptRoot "generators\*.ps1"
$testScriptHtml = $testScripts | ForEach-Object {& $_}

$htmlPrefix = @'
<!DOCTYPE html>
<html lang="en-US">
    <head>
        <meta charset="UTF-8" />
        <title>Script Test Results</title>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.0/styles/default.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.3/highlight.min.js"></script>
        <script charset="UTF-8" src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.0.3/languages/powershell.min.js"></script>
        <script>hljs.initHighlightingOnLoad();</script>
    </head>
    <body>
'@

$htmlSuffix = @'
    </body>
</html>
'@

Write-Output "$htmlPrefix $testScriptHtml $htmlSuffix"
