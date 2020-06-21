function AddScriptMethod {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [String] $TypeName,
        [Parameter(Mandatory)]
        [String] $MethodName,
        [Parameter(Mandatory)]
        [ScriptBlock] $Definition
    )

    Update-TypeData -TypeName $TypeName -MemberName $MethodName `
        -MemberType ScriptMethod -Value $Definition -Force
}

function GetIndent {
    [CmdletBinding()]
    [OutputType([Byte])]
    param(
        [Parameter(Mandatory)]
        [String] $Line
    )

    [Byte] $indent = 0
    foreach ($char in $line.ToCharArray()) {
        if ($char -ne " ") {
            break
        }
        $indent += 1
    }
    return $indent
}

function FormatPageText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    [String] $normalizedText = $Text -replace "`r", ""
    [String[]] $lines = $normalizedText -split "`n"

    # Remove any blank leading or ending lines.
    while ($lines.Length -gt 0) {
        if ($lines[0].Trim().Length -gt 0) {
            break
        }
        $lines = $lines[1..($lines.Length - 1)]
    }
    while ($lines.Length -gt 0) {
        if ($lines[$lines.Length - 1].Trim().Length -gt 0) {
            break
        }
        $lines = $lines[0..($lines.Length - 2)]
    }

    [Byte] $minIndent = ($lines |`
        Where-Object { $_.Length -gt 0 } |`
        ForEach-Object { GetIndent $_ } |`
        Measure-Object -Minimum).Minimum
    [String[]] $deindentedLines = $lines |`
        ForEach-Object {
            $_.Length -gt 0 ?
                $_[$minIndent..($_.Length - 1)] -join "" :
                $_
        }

    [String] $formattedText = $deindentedLines -join "`n"
    return $formattedText
}
