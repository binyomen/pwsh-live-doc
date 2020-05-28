using namespace System.Management.Automation

$windowsPowershellExes = @(
    "powershell -Version 2",
    "powershell -Version 5.1"
)

function GetPowerShellExesToTest {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    $packageDir = "$PSScriptRoot\..\pwsh-packages"
    $packages = Get-ChildItem $packageDir
    $packageExes = $packages | ForEach-Object { "$($_.FullName)\pwsh.exe" }

    return $windowsPowershellExes + $packageExes
}

function RemoveBom {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $InputString
    )

    $bomString = [System.Text.Encoding]::UTF8.GetString(@(239, 187, 191))

    # Remove the BOM from the beginning of the string.
    $InputString -replace "^$bomString", ""
}

function GetExeVersion {
    [CmdletBinding()]
    [OutputType([SemanticVersion])]
    param(
        [String] $Exe
    )

    $rawVersionString = Invoke-Expression "$Exe -NoProfile -c `"```$PSVersionTable.PSVersion.ToString()`""

    # Sometimes with PowerShell v2 there's a BOM at the beginning of the output string.
    $versionString = RemoveBom $rawVersionString

    if ($Exe -in $windowsPowershellExes) {
        $legacyVersion = [Version]::new($versionString)
        $version = [SemanticVersion]::new(`
            $legacyVersion.Major,`
            $legacyVersion.Minor,`
            $legacyVersion.Revision -ge 0 ? $legacyVersion.Revision : 0)
    } else {
        $version = [SemanticVersion]::new($versionString)
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

    $tempScript = New-Item "Temp:\$(New-Guid).ps1"
    try {
        $header = "Import-Module -Force $PSScriptRoot\..\util"
        Set-Content $tempScript.FullName "$header; $Expr"
        $result = Invoke-Expression "$Exe -NoProfile -File $tempScript"

        # Sometimes with PowerShell v2 there's a BOM at the beginning of the
        # output string.
        return RemoveBom ($result -join "`n")
    } finally {
        Remove-Item -Force $tempScript
    }
}
