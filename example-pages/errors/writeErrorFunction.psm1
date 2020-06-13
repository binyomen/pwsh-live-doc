function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'The WriteError function'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputHeading 1 'Catching inside functions'

    OutputText @'
    When `$ErrorActionPreference` is `Stop`, `$PSCmdlet.WriteError` exits the
    current advanced function and throws. However, the exception it throws is
    not catchable from within the advanced function.

    It's worth noting that in PowerShell 2, the exception is caught both inside
    the function and outside the function. Inside the function we catch a "The
    pipeline has been stopped." error, and then continue execution within the
    function. When the function exits, we then throw the original exception.
'@

    OutputCode {
        function TestWriteErrorFunction {
            [CmdletBinding()]
            param()

            $local:ErrorActionPreference = "Stop"
            try {
                $PSCmdlet.WriteError((NewErrorRecord "error in try"))
            } catch {
                Write-Output "caught inside the function: $_"
            }

            Write-Output "after the try-catch"
        }

        try {
            TestWriteErrorFunction
        } catch {
            Write-Output "caught outside the function: $_"
        }
    }

    OutputText @'
    `Write-Error`, on the other hand, is catchable inside the function, for
    both advanced and basic functions.
'@

    OutputCode {
        function TestWriteErrorCmdletAdvanced {
            [CmdletBinding()]
            param()

            $local:ErrorActionPreference = "Stop"
            try {
                Write-Error "error in try"
            } catch {
                Write-Output "caught inside the function: $_"
            }

            Write-Output "after the try-catch"
        }

        function TestWriteErrorCmdletBasic {
            param()

            $local:ErrorActionPreference = "Stop"
            try {
                Write-Error "error in try"
            } catch {
                Write-Output "caught inside the function: $_"
            }

            Write-Output "after the try-catch"
        }

        Write-Output "testing advanced function"
        try {
            TestWriteErrorCmdletAdvanced
        } catch {
            Write-Output "caught outside the function: $_"
        }

        Write-Output ""

        Write-Output "testing basic function"
        try {
            TestWriteErrorCmdletBasic
        } catch {
            Write-Output "caught outside the function: $_"
        }
    }

    OutputHeading 1 'Setting $?'

    OutputText @'
    The `WriteError` function differs from `Write-Error` in another way as
    well. When used inside a function, either advanced or basic, `Write-Error`
    will not set `$?` to false after the function exits. `WriteError`, on the
    other hand, will set `$?` to false after the function exits.

    Interestingly, `Write-Error` will set `$?` to false within its own scope.
    `WriteError`, however, won't touch `$?` until the function exits.
'@

    OutputCode {
        function AdvancedWriteErrorCmdlet {
            [CmdletBinding()]
            param()

            $local:ErrorActionPreference = "SilentlyContinue"
            Write-Error "an error"

            Write-Output "Inside advanced function calling Write-Error status: $?"
        }

        function BasicWriteErrorCmdlet {
            param()

            $local:ErrorActionPreference = "SilentlyContinue"
            Write-Error "an error"

            Write-Output "Inside basic function calling Write-Error status: $?"
        }

        function AdvancedWriteErrorFunction {
            [CmdletBinding()]
            param()

            $local:ErrorActionPreference = "SilentlyContinue"
            $PSCmdlet.WriteError((NewErrorRecord "an error"))

            Write-Output "Inside advanced function calling `$PSCmdlet.WriteError status: $?"
        }

        AdvancedWriteErrorCmdlet
        Write-Output "Advanced function calling Write-Error exited with: $?"
        Write-Output ""

        BasicWriteErrorCmdlet
        Write-Output "Basic function calling Write-Error exited with: $?"
        Write-Output ""

        AdvancedWriteErrorFunction
        Write-Output "Advanced function calling `$PSCmdlet.WriteError exited with: $?"
    }
}
