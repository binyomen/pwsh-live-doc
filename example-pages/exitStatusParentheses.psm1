function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'Variable $? in parentheses'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputText @'
    In PowerShell, the `$?` variable represents the exit status of the previous
    command. If it's true, the command succeeded. If it's false, the command
    failed. However, you need to be careful if using the variable, since
    enclosing a command in parentheses can reset `$?` to true in PowerShell 6
    and earlier.
'@

    OutputCode {
        $local:ErrorActionPreference = "SilentlyContinue"

        Write-Error error
        Write-Output "outside of parentheses: `$? = $?"

        (Write-Error error)
        Write-Output "inside of parentheses: `$? = $?"
    }
}
