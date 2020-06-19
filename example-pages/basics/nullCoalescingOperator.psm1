function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'The null-coalescing operator'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputSection 'Double evaluation of first argument' {
        OutputText @'
        The null-coalescing operator was introduced in PowerShell 7. In
        versions 7.0.0 and 7.0.1, however, the first argument of the operator
        is evaluated twice if it's not null.

        Notice that "ran func" is only printed out once even though the counter
        is incremented twice. This is because the actual output of the function
        is only used once, while any side effects such as incrementing a
        counter or calling `Write-Host` would occur twice.
'@

        OutputCode -MinVersion 7 {
            $global:counter = 0
            function func {
                $global:counter += 1
                Write-Output 'ran func'
            }

            (func) ?? 'func returned null'
            Write-Output "Counter: $global:counter"
        }

        OutputText @'
        If the first argument is null, it's only evaluated once.
'@

        OutputCode -MinVersion 7 {
            $global:counter = 0
            function func {
                $global:counter += 1
            }

            (func) ?? 'func returned null'
            Write-Output "Counter: $global:counter"
        }
    }
}
