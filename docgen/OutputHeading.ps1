function MakeHeading {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $TagName,
        [Parameter(Mandatory)]
        [String] $Content
    )

    return "<$TagName>$Content</$TagName>"
}


function OutputHeading {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $Level,
        [Parameter(Mandatory)]
        [String] $Text
    )

    switch ($Level) {
        1 { return MakeHeading "h3" $Text }
        2 { return MakeHeading "h4" $Text }
        3 { return MakeHeading "h5" $Text }
        4 { return MakeHeading "h6" $Text }
        default { throw "Invalid heading level" }
    }
}
