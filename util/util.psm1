function NewErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [String] $Text
    )

    return [System.Management.Automation.ErrorRecord]::new(
        # The underlying .NET exception: if you pass a string, as here, PS
        # creates a [System.Exception] instance.
        $Text,
        $null, # error ID
        [System.Management.Automation.ErrorCategory]::InvalidData, # error category
        $null) # offending object
}
Export-ModuleMember -Function NewErrorRecord
