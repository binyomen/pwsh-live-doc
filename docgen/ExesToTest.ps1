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
        [String] $LineText,
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
        LineText = $LineText
        Stdout = $Stdout
        Stderr = $Stderr
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

AddScriptMethod ExampleOutput GetLine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $LineNumber
    )

    foreach ($line in $this.Lines) {
        if ($line.LineNumber -eq $LineNumber) {
            return $line
        }
    }
    return $null
}

function TakeSuffix {
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $PrefixLength,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Object[]] $List
    )

    if (($List.Count -eq 0) -or ($PrefixLength -eq $List.Count)) {
        return ,@()
    } else {
        return $List[$PrefixLength..($List.Count - 1)]
    }
}

function CreateLineOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [UInt32] $CurrentStdoutLines,
        [Parameter(Mandatory)]
        [UInt32] $CurrentStderrLines,
        [Parameter(Mandatory)]
        [UInt32] $LineNumber,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $LineText,
        [Parameter(Mandatory)]
        [FileInfo] $StdoutFile,
        [Parameter(Mandatory)]
        [FileInfo] $StderrFile
    )

    # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
    [String[]] $stdout = BreakIntoLines (RemoveBom (Get-Content -Raw $StdoutFile))
    [String[]] $stderr = BreakIntoLines (RemoveBom (Get-Content -Raw $StderrFile))

    [String] $newStdout = (TakeSuffix $CurrentStdoutLines $stdout) -join "`n"
    [String] $newStderr = (TakeSuffix $CurrentStderrLines $stderr) -join "`n"

    return NewLineOutput $LineNumber $LineText $newStdout $newStderr
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

    [UInt32] $totalStdoutLines = 0
    [UInt32] $totalStderrLines = 0
    [UInt32] $previousLineNumber = 0
    [String] $previousLineText = $null
    while ($true) {
        [UInt32] $lineNumber = $reader.ReadLine()
        if ($lineNumber -eq 0) {
            break
        }
        [String] $lineText = $reader.ReadLine()

        if ($previousLineNumber -gt 0) {
            [PSCustomObject] $lineOutput = `
                CreateLineOutput $totalStdoutLines $totalStderrLines $previousLineNumber $previousLineText $stdoutFile $stderrFile
            $totalStdoutLines += (BreakIntoLines $lineOutput.Stdout).Count
            $totalStderrLines += (BreakIntoLines $lineOutput.Stderr).Count
            $lineOutputs += $lineOutput
        }

        $previousLineNumber = $lineNumber
        $previousLineText = $lineText
        $writer.WriteLine('ready')
    }

    $process.WaitForExit()

    # Get the output from the last line.
    $lineOutputs += `
        CreateLineOutput $totalStdoutLines $totalStderrLines $previousLineNumber $previousLineText $stdoutFile $stderrFile

    [PSCustomObject] $output = NewExampleOutput $Exe.Version $lineOutputs
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
                    "-Action { RecordLine $tempScript $i > `$null } > `$null; "
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
