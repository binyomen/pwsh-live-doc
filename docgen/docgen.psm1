function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $Text
    )

    return "<p>" + $Text + "</p>"
}
Export-ModuleMember -Function OutputText

function OutputCode {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [ScriptBlock] $Code
    )

    Import-Module -Force $PSScriptRoot\..\util

    $formattedCode = "<pre><code class=`"powershell`">" + $Code.ToString() + "</code></pre>"
    $formattedOutput = "<p>" + (& $Code) + "</p>"
    return $formattedCode + "`n" + $formattedOutput
}
Export-ModuleMember -Function OutputCode
