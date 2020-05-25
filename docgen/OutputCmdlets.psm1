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

    Import-Module -Force $PSScriptRoot\..\util

    $codeAsString = $Code.ToString()
    $codeDeindented = Deindent $codeAsString
    $formattedCode = "<pre><code class=`"powershell`">" + $codeDeindented + "</code></pre>"

    $commandOutput = Invoke-Expression $Code.ToString()
    $stringCommandOutput = $commandOutput -join "`n"
    $formattedCommandOutput = "<pre><p>" + $stringCommandOutput + "</p></pre>"

    return $formattedCode + "`n" + $formattedCommandOutput
}
