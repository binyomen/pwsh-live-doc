Set-StrictMode -Version Latest
$script:ErrorActionPreference = "Stop"

function NewErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory=$true)]
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

[System.IO.Pipes.NamedPipeClientStream] $script:client = `
    New-Object System.IO.Pipes.NamedPipeClientStream( `
        '.', `
        (Get-Item .).Name, `
        [System.IO.Pipes.PipeDirection]::InOut, `
        [System.IO.Pipes.PipeOptions]::None, `
        [System.Security.Principal.TokenImpersonationLevel]::Impersonation)
$script:client.Connect()

[System.IO.StreamReader] $script:reader = New-Object System.IO.StreamReader($client)
[System.IO.StreamWriter] $script:writer = New-Object System.IO.StreamWriter($client)
$script:writer.AutoFlush = $true

function RecordLine {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        # Powershell version 2 doesn't support passing in the current
        # breakpoint as $_ to the -Action parameter, so we need to handle
        # passing in the line number ourselves.
        [Parameter(Mandatory=$true)]
        [UInt32] $LineNumber
    )

    $script:writer.WriteLine($LineNumber)
    $script:reader.ReadLine() > $null

    $script:currentBreakpointIndex += 1
}
Export-ModuleMember -Function RecordLine
