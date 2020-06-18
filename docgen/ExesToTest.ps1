[String[]] $script:windowsPowershellExes = @(
    "powershell -Version 2",
    "powershell -Version 5.1"
)

[Tuple[String, SemanticVersion][]] $script:allExeTuples = @()

function GetPowerShellExesToTest {
    [CmdletBinding()]
    [OutputType([Tuple[String, SemanticVersion][]])]
    param(
        [SemanticVersion] $MinVersion = [SemanticVersion]::new(0)
    )

    if ($script:allExeTuples.Count -eq 0) {
        Write-Host "Caching list of exes..."

        [String] $packageDir = "$PSScriptRoot\..\pwsh-packages"
        [DirectoryInfo[]] $packages = Get-ChildItem $packageDir
        [String[]] $packageExes = $packages | ForEach-Object { "$($_.FullName)\pwsh.exe" }

        [String[]] $allExes = $windowsPowershellExes + $packageExes

        $script:allExeTuples = $allExes |`
            ForEach-Object { [Tuple]::Create($_, (GetExeVersion $_)) }
    }

    return $script:allExeTuples |`
        Where-Object {
            [Tuple[String, SemanticVersion]] $tuple = $_
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
        [String] $Exe
    )

    if ($Exe -match 'v([0-9]+\.[0-9]+\.[0-9]+)\\pwsh.exe$') {
        [SemanticVersion] $version = [SemanticVersion]::new($matches[1])
    } else {
        [String] $rawVersionString = Invoke-Expression "$Exe -NoProfile -Command `"```$PSVersionTable.PSVersion.ToString()`""

        # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
        [String] $versionString = RemoveBom $rawVersionString

        if ($Exe -in $windowsPowershellExes) {
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

function RunAndGatherOutput {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [DirectoryInfo] $WorkingDir,
        [Parameter(Mandatory)]
        [String] $CommandLine
    )

    Push-Location $WorkingDir
    try {
        [String[]] $result = Invoke-Expression $CommandLine

        # Sometimes with PowerShell v2 there's a BOM at the beginning of the
        # output string.
        return RemoveBom ($result -join "`n")
    } finally {
        Pop-Location
    }
}

function InvokeExe {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Exe,
        [Parameter(Mandatory)]
        [String] $Expr
    )

    [FileInfo] $tempScript = New-Item "Temp:\pwsh-live-doc_$(New-Guid)\__script.ps1" -Force
    try {
        [String] $header = "Import-Module -Force $PSScriptRoot\..\util"
        Set-Content $tempScript.FullName "$header; $Expr"
        [String[]] $output = RunAndGatherOutput $tempScript.Directory "$Exe -NoProfile -NonInteractive -File $tempScript"

        return $output
    } finally {
        Remove-Item $tempScript.Directory -Recurse -Force
    }
}
