function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    [String] $formattedText = FormatPageText $Text
    return (ConvertFrom-Markdown -InputObject $formattedText).Html
}
