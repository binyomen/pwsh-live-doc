[Tuple[String, String][]] $script:windowsPowershellCommands = @(
    [Tuple]::Create('powershell', '-Version 2'),
    [Tuple]::Create('powershell', '-Version 5.1')
)

[PSCustomObject] $script:allExes = @()

function NewPwshExe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [String] $File,
        [String] $InitialArgs = ''
    )

    [String] $command = $InitialArgs.Length -eq 0 ? $File : "$File $InitialArgs"

    [SemanticVersion] $version = GetExeVersion $command

    return [PSCustomObject]@{
        PSTypeName = 'PwshExe'
        File = $File
        InitialArgs = $InitialArgs
        Version = $version
    }
}

function GetPowerShellExesToTest {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [SemanticVersion] $MinVersion = [SemanticVersion]::new(0)
    )

    if ($script:allExes.Count -eq 0) {
        Write-Host "Caching list of exes..."

        [String] $packageDir = "$PSScriptRoot\..\pwsh-packages"
        [DirectoryInfo[]] $packages = Get-ChildItem $packageDir
        [String[]] $packageCommands = $packages | ForEach-Object { "$($_.FullName)\pwsh.exe" }

        [PSCustomObject[]] $packageExes = $packageCommands | `
            ForEach-Object { NewPwshExe $_ }
        [PSCustomObject[]] $windowsPowershellExes = $script:windowsPowershellCommands | `
            ForEach-Object { NewPwshExe $_.Item1 $_.Item2 }

        $script:allExes = $packageExes + $windowsPowershellExes
    }

    return $script:allExes |`
        Where-Object {
            [PSCustomObject] $exe = $_
            if ($script:options.TestOnlyMajorVersions) {
                return ($exe.Version.Major -eq 2) -or
                    ($exe.Version.Major -eq 5) -or
                    (($exe.Version.Minor -eq 0) -and ($exe.Version.Patch -eq 0))
            } else {
                return $true
            }
        } | `
        Where-Object { $_.Version -ge $MinVersion }
}

function RemoveBom {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $InputString
    )

    [String] $bomString = [Encoding]::UTF8.GetString(@(239, 187, 191))

    # Remove the BOM from the beginning of the string.
    return $InputString -replace "^$bomString", ""
}

function GetExeVersion {
    [CmdletBinding()]
    [OutputType([SemanticVersion])]
    param(
        [Parameter(Mandatory)]
        [String] $Command
    )

    if ($Command -match 'v([0-9]+\.[0-9]+\.[0-9]+)\\pwsh.exe$') {
        # Just get the version from the file path, which is much more efficient
        # than running the exe.
        [SemanticVersion] $version = [SemanticVersion]::new($matches[1])
    } else {
        [String] $rawVersionString = Invoke-Expression "$Command -NoProfile -NonInteractive -Command `"```$PSVersionTable.PSVersion.ToString()`""

        # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
        [String] $versionString = RemoveBom $rawVersionString

        if ($Command.StartsWith('powershell')) {
            [Version] $legacyVersion = [Version]::new($versionString)
            [SemanticVersion] $version = [SemanticVersion]::new(`
                $legacyVersion.Major,`
                $legacyVersion.Minor,`
                $legacyVersion.Revision -ge 0 ? $legacyVersion.Revision : 0)
        } else {
            [SemanticVersion] $version = [SemanticVersion]::new($versionString)
        }
    }

    return $version
}

function NewLineOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $LineNumber,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Stdout,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Stderr
    )

    return [PSCustomObject]@{
        PSTypeName = 'LineOutput'
        LineNumber = $LineNumber
        Stdout = $Stdout
        Stderr = $Stderr
        StdoutStartsLine = $true
        StderrStartsLine = $true
        StdoutEndsLine = $true
        StderrEndsLine = $true
    }
}

function NewExampleOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $Version,
        [Parameter(Mandatory)]
        [PSTypeName('LineOutput')]
        [PSCustomObject[]] $Lines
    )

    return [PSCustomObject]@{
        PSTypeName = 'ExampleOutput'
        Version = $Version
        Lines = $Lines
    }
}

AddScriptMethod ExampleOutput Stdout {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [String[]] $streamList = @()
    foreach ($line in $this.Lines) {
        if ($line.Stdout.Length -ne 0) {
            $streamList += $line.Stdout
        }
    }
    return $streamList -join ''
} ScriptProperty

AddScriptMethod ExampleOutput Stderr {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [String[]] $streamList = @()
    foreach ($line in $this.Lines) {
        if ($line.Stderr.Length -ne 0) {
            $streamList += $line.Stderr
        }
    }
    return $streamList -join ''
} ScriptProperty

AddScriptMethod ExampleOutput StdoutStartsLine {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    foreach ($line in $this.Lines) {
        if ($line.Stdout.Length -gt 0) {
            return $line.StdoutStartsLine
        }
    }
    return $false
} ScriptProperty

AddScriptMethod ExampleOutput StderrStartsLine {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    foreach ($line in $this.Lines) {
        if ($line.Stderr.Length -gt 0) {
            return $line.StderrStartsLine
        }
    }
    return $false
} ScriptProperty

AddScriptMethod ExampleOutput StdoutEndsLine {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    [Boolean] $stdoutEndsLine = $true
    foreach ($line in $this.Lines) {
        if ($line.Stdout.Length -gt 0) {
            $stdoutEndsLine = $line.StdoutEndsLine
        }
    }
    return $stdoutEndsLine
} ScriptProperty

AddScriptMethod ExampleOutput StderrEndsLine {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    [Boolean] $stderrEndsLine = $true
    foreach ($line in $this.Lines) {
        if ($line.Stderr.Length -gt 0) {
            $stderrEndsLine = $line.StderrEndsLine
        }
    }
    return $stderrEndsLine
} ScriptProperty

AddScriptMethod ExampleOutput GetLines {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $LineNumber
    )

    return ,@($this.Lines | Where-Object { $_.LineNumber -eq $LineNumber })
}

function RemovePrefix {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $PrefixLength,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $String
    )

    if (($String.Length -eq 0) -or ($PrefixLength -eq $String.Length)) {
        return ''
    } else {
        return $String[$PrefixLength..($String.Length - 1)] -join ''
    }
}

function StartsLine {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $AllOutput,
        [Parameter(Mandatory)]
        [UInt32] $CurrentChars,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $NewOutput
    )

    if (($AllOutput.Length -eq 0) -or ($NewOutput.Length -eq 0)) {
        return $false
    } elseif ($CurrentChars -eq 0) {
        return $true
    } else {
        return $AllOutput[$CurrentChars - 1] -eq "`n"
    }
}

function EndsLine {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $NewOutput
    )

    return ($NewOutput.Length -gt 0) -and ($NewOutput[-1] -eq "`n")
}

function CreateLineOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $CurrentStdoutChars,
        [Parameter(Mandatory)]
        [UInt32] $CurrentStderrChars,
        [Parameter(Mandatory)]
        [UInt32] $LineNumber,
        [Parameter(Mandatory)]
        [FileInfo] $StdoutFile,
        [Parameter(Mandatory)]
        [FileInfo] $StderrFile
    )

    # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
    [String] $stdout = FixNewLines (RemoveBom (Get-Content -Raw $StdoutFile))
    [String] $stderr = FixNewLines (RemoveBom (Get-Content -Raw $StderrFile))

    [String] $newStdout = (RemovePrefix $CurrentStdoutChars $stdout)
    [String] $newStderr = (RemovePrefix $CurrentStderrChars $stderr)

    [PSCustomObject] $line = NewLineOutput $LineNumber $newStdout $newStderr
    if (-not (StartsLine $stdout $CurrentStdoutChars $line.Stdout)) {
        $line.StdoutStartsLine = $false
    }
    if (-not (StartsLine $stderr $CurrentStderrChars $line.Stderr)) {
        $line.StderrStartsLine = $false
    }
    if (-not (EndsLine $line.Stdout)) {
        $line.StdoutEndsLine = $false
    }
    if (-not (EndsLine $line.Stderr)) {
        $line.StderrEndsLine = $false
    }

    return $line
}

function RunAndGatherOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [DirectoryInfo] $WorkingDir,
        [Parameter(Mandatory)]
        [PSTypeName('PwshExe')]
        [PSCustomObject] $Exe,
        [Parameter(Mandatory)]
        [String] $Arguments
    )

    [FileInfo] $stdoutFile = New-Item "$WorkingDir\__stdout"
    [FileInfo] $stderrFile = New-Item "$WorkingDir\__stderr"

    [Process] $process = Start-Process $Exe.File -Args "$($Exe.InitialArgs) $Arguments" `
        -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile `
        -WorkingDirectory $WorkingDir -NoNewWindow -PassThru

    [NamedPipeServerStream] $server = [NamedPipeServerStream]::new($WorkingDir.Name, [PipeDirection]::InOut)
    $server.WaitForConnection()

    [StreamReader] $reader = [StreamReader]::new($server)
    [StreamWriter] $writer = [StreamWriter]::new($server)
    $writer.AutoFlush = $true

    [PSCustomObject[]] $lineOutputs = @()

    [UInt32] $totalStdoutChars = 0
    [UInt32] $totalStderrChars = 0
    [UInt32] $previousLineNumber = 0
    while ($true) {
        [UInt32] $lineNumber = $reader.ReadLine()
        if ($lineNumber -eq 0) {
            break
        }

        if ($previousLineNumber -gt 0) {
            [PSCustomObject] $lineOutput = `
                CreateLineOutput $totalStdoutChars $totalStderrChars $previousLineNumber $stdoutFile $stderrFile
            $totalStdoutChars += $lineOutput.Stdout.Length
            $totalStderrChars += $lineOutput.Stderr.Length
            $lineOutputs += $lineOutput
        }

        $previousLineNumber = $lineNumber
        $writer.WriteLine('ready')
    }

    $process.WaitForExit()

    # Get the output from the last line.
    $lineOutputs += `
        CreateLineOutput $totalStdoutChars $totalStderrChars $previousLineNumber $stdoutFile $stderrFile

    [PSCustomObject] $output = NewExampleOutput $Exe.Version $lineOutputs
    [String] $stdout = FixNewLines (RemoveBom (Get-Content -Raw $StdoutFile))
    [String] $stderr = FixNewLines (RemoveBom (Get-Content -Raw $StderrFile))
    if (($output.Stdout -ne $stdout) -or ($output.Stderr -ne $stderr)) {
        throw 'Did not properly collect stdio'
    }

    return $output
}

function InvokeExe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('PwshExe')]
        [PSCustomObject] $Exe,
        [Parameter(Mandatory)]
        [String] $Code
    )

    [FileInfo] $tempScript = New-Item "Temp:\pwsh-live-doc_$(New-Guid)\__script.ps1" -Force
    try {
        Set-Content $tempScript.FullName $Code
        [String[]] $lines = Get-Content $tempScript
        [String] $breakpointString = ''
        foreach ($i in 1..$lines.Count) {
            $breakpointString += `
                "Set-PSBreakpoint -Script $tempScript -Line $i " +
                    "-Action { RecordLine $i > `$null } > `$null; "
        }

        [String] $command = `
            "Import-Module -Force $PSScriptRoot\..\util; " +
            $breakpointString +
            "$tempScript;"
        [PSCustomObject] $output = RunAndGatherOutput $tempScript.Directory $Exe "-NoProfile -NonInteractive -Command $command"

        return $output
    } finally {
        # The stdio files may still be open by the process, even though
        # PowerShell says it's exited. Keep trying until we can delete them.
        [UInt32] $tries = 0
        while ($true) {
            try {
                Remove-Item $tempScript.Directory -Recurse -Force
                break
            } catch {
                $tries += 1
                # The file should be deletable eventually, but PowerShell can
                # sometimes take a while to run down, so give lots of wiggle room.
                if ($tries -gt 1000) {
                    throw $_
                }

                Start-Sleep -Milliseconds 30
            }
        }
    }
}
