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

function NewExampleOutput {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $Version,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Stdout,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Stderr
    )

    return [PSCustomObject]@{
        PSTypeName = 'ExampleOutput'
        Version = $Version
        Stdout = $Stdout
        Stderr = $Stderr
    }
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

    Start-Process $Exe.File -Args "$($Exe.InitialArgs) $Arguments" `
        -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile `
        -WorkingDirectory $WorkingDir -Wait -NoNewWindow

    # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
    [String] $stdout = FixNewLines (RemoveBom (Get-Content -Raw $stdoutFile))
    [String] $stderr = FixNewLines (RemoveBom (Get-Content -Raw $stderrFile))

    return NewExampleOutput $Exe.Version $stdout $stderr
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
        [String] $command = "Import-Module -Force $PSScriptRoot\..\util; $tempScript;"

        return RunAndGatherOutput $tempScript.Directory $Exe "-NoProfile -NonInteractive -Command $command"
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
