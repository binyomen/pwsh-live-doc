using namespace System.IO
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$script:ErrorActionPreference = "Stop"

[String[]] $windowsPowershellExes = @(
    "powershell -Version 2",
    "powershell -Version 5.1"
)

function GetPowerShellExesToTest {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    [String] $packageDir = "$PSScriptRoot\..\pwsh-packages"
    [DirectoryInfo[]] $packages = Get-ChildItem $packageDir
    [String[]] $packageExes = $packages | ForEach-Object { "$($_.FullName)\pwsh.exe" }

    return $windowsPowershellExes + $packageExes
}

function RemoveBom {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $InputString
    )

    [String] $bomString = [System.Text.Encoding]::UTF8.GetString(@(239, 187, 191))

    # Remove the BOM from the beginning of the string.
    return $InputString -replace "^$bomString", ""
}

function GetExeVersion {
    [CmdletBinding()]
    [OutputType([SemanticVersion])]
    param(
        [String] $Exe
    )

    [String] $rawVersionString = Invoke-Expression "$Exe -NoProfile -c `"```$PSVersionTable.PSVersion.ToString()`""

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

    return $version
}

function InvokeExe {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $Exe,
        [String] $Expr
    )

    [FileInfo] $tempScript = New-Item "Temp:\$(New-Guid).ps1"
    try {
        [String] $header = "Import-Module -Force $PSScriptRoot\..\util"
        Set-Content $tempScript.FullName "$header; $Expr"
        [String[]] $result = Invoke-Expression "$Exe -NoProfile -File $tempScript"

        # Sometimes with PowerShell v2 there's a BOM at the beginning of the
        # output string.
        return RemoveBom ($result -join "`n")
    } finally {
        Remove-Item -Force $tempScript
    }
}
