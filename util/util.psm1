function NewErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [String] $Text
    )

    if ($PSVersionTable.PSVersion.ToString() -eq "2.0") {
        # PowerShell version 2 doesn't support the `new` syntax for
        # constructors, so use `New-Object` instead. I could have also just
        # always used `New-Object` since it works with both, but ¯\_(ツ)_/¯.
        return New-Object System.Management.Automation.ErrorRecord -Args @(
            # The underlying .NET exception: if you pass a string, as here, PS
            # creates a [System.Exception] instance.
            $Text,
            $null, # error ID
            [System.Management.Automation.ErrorCategory]::InvalidData, # error category
            $null) # offending object
    } else {
        return [System.Management.Automation.ErrorRecord]::new(
            # The underlying .NET exception: if you pass a string, as here, PS
            # creates a [System.Exception] instance.
            $Text,
            $null, # error ID
            [System.Management.Automation.ErrorCategory]::InvalidData, # error category
            $null) # offending object
    }
}
Export-ModuleMember -Function NewErrorRecord
