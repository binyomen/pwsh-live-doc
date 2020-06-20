[String[][]] $script:windowsPowershellExes = @(
    @('powershell', '-Version', '2'),
    @('powershell', '-Version', '5.1')
)

[Tuple[[String[]], System.Management.Automation.SemanticVersion][]] $script:allExeTuples = @()

function GetPowerShellExesToTest {
    [CmdletBinding()]
    [OutputType([Tuple[[String[]], SemanticVersion][]])]
    param(
        [SemanticVersion] $MinVersion = [SemanticVersion]::new(0)
    )

    if ($script:allExeTuples.Count -eq 0) {
        Write-Host "Caching list of exes..."

        [String] $packageDir = "$PSScriptRoot\..\pwsh-packages"
        [DirectoryInfo[]] $packages = Get-ChildItem $packageDir
        [String[]] $packageExes = $packages | ForEach-Object { ,@("$($_.FullName)\pwsh.exe") }

        [String[][]] $allExes = $windowsPowershellExes + $packageExes

        $script:allExeTuples = $allExes |`
            ForEach-Object { [Tuple]::Create($_, (GetExeVersion $_)) }
    }

    return $script:allExeTuples |`
        Where-Object {
            [Tuple[[String[]], SemanticVersion]] $tuple = $_
            if ($script:options.TestOnlyMajorVersions) {
                return ($tuple.Item2.Major -eq 2) -or
                    ($tuple.Item2.Major -eq 5) -or
                    (($tuple.Item2.Minor -eq 0) -and ($tuple.Item2.Patch -eq 0))
            } else {
                return $true
            }
        } |`
        Where-Object { $_.Item2 -ge $MinVersion }
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
        [String[]] $Exe
    )

    if ($Exe[0] -match 'v([0-9]+\.[0-9]+\.[0-9]+)\\pwsh.exe$') {
        [SemanticVersion] $version = [SemanticVersion]::new($matches[1])
    } else {
        [String] $rawVersionString = Invoke-Expression "$Exe -NoProfile -Command `"```$PSVersionTable.PSVersion.ToString()`""

        # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
        [String] $versionString = RemoveBom $rawVersionString

        if ($Exe[0] -eq 'powershell') {
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
        [AllowEmptyString()]
        [String] $Stdout,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Stderr
    )

    return [PSCustomObject]@{
        PSTypeName = 'ExampleOutput'
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
        [String[]] $Exe,
        [Parameter(Mandatory)]
        [String] $Arguments
    )

    [FileInfo] $stdoutFile = New-Item "$WorkingDir\__stdout"
    [FileInfo] $stderrFile = New-Item "$WorkingDir\__stderr"

    [String] $exeFile = $Exe[0]
    [String[]] $exeArgs = $Exe.Count -gt 1 ? $Exe[1..($Exe.Count - 1)] : @()

    Start-Process $exeFile -Args ($exeArgs + $Arguments) `
        -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile `
        -WorkingDirectory $WorkingDir -Wait -NoNewWindow

    [String] $stdout = Get-Content -Raw $stdoutFile
    [String] $stderr = Get-Content -Raw $stderrFile

    # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
    [PSCustomObject] $output = NewExampleOutput (RemoveBom $stdout) (RemoveBom $stderr)
    return $output
}

function InvokeExe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [String[]] $Exe,
        [Parameter(Mandatory)]
        [String] $Code
    )

    [FileInfo] $tempScript = New-Item "Temp:\pwsh-live-doc_$(New-Guid)\__script.ps1" -Force
    try {
        [String] $header = "Import-Module -Force $PSScriptRoot\..\util"
        Set-Content $tempScript.FullName "$header; $Code"
        [PSCustomObject] $output = RunAndGatherOutput $tempScript.Directory $Exe "-NoProfile -NonInteractive -File $tempScript"

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
