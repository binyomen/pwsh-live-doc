Import-Module -Force $PSScriptRoot\docgen

OutputText @'
When $ErrorActionPreference is "Stop", $PSCmdlet.WriteError exits the current
advanced function and throws. However, the exception it throws is not catchable
from within the advanced function.
'@

OutputCode {
    New-Module {
        Import-Module -Force $PSScriptRoot\util

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
        Export-ModuleMember -Function TestWriteErrorFunction
    } > $null

    try {
        TestWriteErrorFunction
    } catch {
        Write-Output "caught outside the cmdlet: $_"
    }
}
