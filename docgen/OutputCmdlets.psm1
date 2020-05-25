using namespace System.Management.Automation

function OutputTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    return "<h2>$Text</h2>"
}

function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    return "<p>" + $Text + "</p>"
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
    $formattedCode = "<pre><code class=`"powershell`">" + $codeDeindented + "</code></pre>"

    $exesToTest = GetPowerShellExesToTest

    $outputToVersionMap = @{}
    $allVersions = @()
    foreach ($exe in $exesToTest) {
        $commandOutput = InvokeExe $exe $Code.ToString()
        $stringCommandOutput = $commandOutput -join "`n"
        $formattedCommandOutput = "<pre><p>" + $stringCommandOutput + "</p></pre>"

        if (-not $outputToVersionMap.ContainsKey($formattedCommandOutput)) {
            $outputToVersionMap[$formattedCommandOutput] = @()
        }

        $version = GetExeVersion $exe
        $outputToVersionMap[$formattedCommandOutput] += $version
        $allVersions += $version
    }

    $outputTableHtml = "<table><thead><tr>"

    $outputs = $outputToVersionMap.Keys
    foreach ($output in $outputs) {
        $generalizedVersions = GeneralizeVersions $allVersions $outputToVersionMap[$output] | Sort-Object
        $outputTableHtml += "<th>$($generalizedVersions -join ", ")</th>"
    }

    $outputTableHtml += "</tr></thead><tbody><tr>"

    foreach ($output in $outputs) {
        $outputTableHtml += "<td>$output</td>"
    }

    $outputTableHtml += "</tr></tbody></table>"

    return $formattedCode + $outputTableHtml
}
