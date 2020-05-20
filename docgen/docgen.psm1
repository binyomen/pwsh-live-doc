function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $Text
    )

    return "<p>" + $Text + "</p>"
}
Export-ModuleMember -Function OutputText

function Deindent {
    [CmdletBinding()]
    [OutputType([String])]
    param(
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
Export-ModuleMember -Function OutputCode
