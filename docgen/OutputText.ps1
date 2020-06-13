function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    [String] $formattedText = FormatPageText $Text
    [String] $rawHtml = (ConvertFrom-Markdown -InputObject $formattedText).Html
    return $rawHtml -replace "<p>", "<p class=`"content-text`">"
}
