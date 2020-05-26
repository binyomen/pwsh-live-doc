using namespace System.Management.Automation

function OutputTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    Write-Host "Running tests for '$Text'"
    return "<h2>$Text</h2>"
}

function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    return (ConvertFrom-Markdown -InputObject $Text).Html
}

function Deindent {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $StringToDeindent
    )

    $lines = $StringToDeindent -split "`n"

    # there's always a blank line first
    $linesWithoutFirstLine = $lines[1..$lines.Length]

    $deindentedLines = $linesWithoutFirstLine -split "`n" | ForEach-Object { $_[4..$_.Length] -join "" }
    $deindentedLines -join "`n"
}

function OutputCode {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $Code
    )

    $codeAsString = $Code.ToString()
    $codeDeindented = Deindent $codeAsString
    $formattedCode = "<pre class=`"code-view`"><code class=`"powershell`">" + $codeDeindented + "</code></pre>"

    $outputTableHtml = "<table class=`"output-table`"><caption>Output by version</caption><thead><tr>"

    $exesToTest = GetPowerShellExesToTest

    # Create a map of output string to list of versions. This lets us group
    # versions by what their output is.
    $outputToVersionMap = @{}
    $allVersions = @()
    foreach ($exe in $exesToTest) {
        Write-Host "Running $exe"

        $commandOutput = InvokeExe $exe $Code.ToString()
        $stringCommandOutput = $commandOutput -join "`n"
        $formattedCommandOutput = "<pre class=`"output-text`">" + $stringCommandOutput + "</pre>"

        if (-not $outputToVersionMap.ContainsKey($formattedCommandOutput)) {
            $outputToVersionMap[$formattedCommandOutput] = @()
        }

        $version = GetExeVersion $exe
        $outputToVersionMap[$formattedCommandOutput] += $version
        $allVersions += $version
    }

    # Now create a map from version string to corresponding output. This lets
    # us sort the version strings without mismatching them with their outputs.
    $versionStringToOutputMap = @{}
    foreach ($output in $outputToVersionMap.Keys) {
        $generalizedVersions = GeneralizeVersions $allVersions $outputToVersionMap[$output] | Sort-Object
        $versionStringToOutputMap["<th>$($generalizedVersions -join ", ")</th>"] = $output
    }

    $sortedVersionKeys = $versionStringToOutputMap.Keys | Sort-Object
    $outputTableHtml += "$sortedVersionKeys"

    $outputTableHtml += "</tr></thead><tbody><tr>"

    foreach ($version in $sortedVersionKeys) {
        $output = $versionStringToOutputMap[$version]
        $outputTableHtml += "<td>$output</td>"
    }

    $outputTableHtml += "</tr></tbody></table>"

    return $formattedCode + $outputTableHtml
}
