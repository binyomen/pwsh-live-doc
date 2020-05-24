Import-Module -Force $PSScriptRoot\..\docgen

OutputText @'
When <code>$ErrorActionPreference</code> is <code>Stop</code>,
<code>$PSCmdlet.WriteError</code> exits the current advanced function and
throws. However, the exception it throws is not catchable from within the
advanced function.
'@

OutputCode {
    function TestWriteErrorFunction {
        [CmdletBinding()]
        param()

        $local:ErrorActionPreference = "Stop"
        try {
            $PSCmdlet.WriteError((NewErrorRecord "error in try"))
        } catch {
            Write-Output "caught inside the cmdlet: $_"
        }

        Write-Output "after the try-catch"
    }

    try {
        TestWriteErrorFunction
    } catch {
        Write-Output "caught outside the cmdlet: $_"
    }
}

OutputText @'
Write-Error, on the other hand, is catchable inside the function, for both
advanced and basic functions.
'@

OutputCode {
    function TestWriteErrorCmdletAdvanced {
        [CmdletBinding()]
        param()

        $local:ErrorActionPreference = "Stop"
        try {
            Write-Error "error in try"
        } catch {
            Write-Output "caught inside the cmdlet: $_"
        }

        Write-Output "after the try-catch"
    }

    function TestWriteErrorCmdletBasic {
        param()

        $local:ErrorActionPreference = "Stop"
        try {
            Write-Error "error in try"
        } catch {
            Write-Output "caught inside the cmdlet: $_"
        }

        Write-Output "after the try-catch"
    }

    Write-Output "testing advanced function"
    try {
        TestWriteErrorCmdletAdvanced
    } catch {
        Write-Output "caught outside the cmdlet: $_"
    }

    Write-Output ""

    Write-Output "testing basic function"
    try {
        TestWriteErrorCmdletBasic
    } catch {
        Write-Output "caught outside the cmdlet: $_"
    }
}
