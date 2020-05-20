function TestWriteErrorFunction {
    [CmdletBinding()]
    param()

    $local:ErrorActionPreference = "Stop"
    try {
        $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
        # The underlying .NET exception: if you pass a string, as here, PS
        # creates a [System.Exception] instance.
        "error in try",
        $null, # error ID
        [System.Management.Automation.ErrorCategory]::InvalidData, # error category
        $null) # offending object
        )
    } catch {
        Write-Host "caught inside the cmdlet"
        $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
            # The underlying .NET exception: if you pass a string, as here, PS
            # creates a [System.Exception] instance.
            "error in catch",
            $null, # error ID
            [System.Management.Automation.ErrorCategory]::InvalidData, # error category
            $null) # offending object
        )
    }

    Write-Host here
}
Export-ModuleMember -Function TestWriteErrorFunction
