using namespace System.Management.Automation

function GetPowerShellExesToTest {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    return @(
        "pwsh",
        "powershell"
    )
}

function GetExeVersion {
    [CmdletBinding()]
    [OutputType([SemanticVersion])]
    param(
        [String] $Exe
    )

    $versionString = Invoke-Expression "$Exe -c `"```$PSVersionTable.PSVersion.ToString()`""

    if ($Exe -eq "powershell") {
        $legacyVersion = [Version]::new($versionString)
        $version = [SemanticVersion]::new($legacyVersion.Major, $legacyVersion.Minor, $legacyVersion.Revision)
    } else {
        $version = [SemanticVersion]::new($versionString)
    }

    return $version
}

function InvokeExe {
    [CmdletBinding()]
    [OutputType([String[]])]
    param(
        [String] $Exe,
        [String] $Expr
    )

    $tempScript = New-Item "Temp:\$(New-Guid).ps1"
    try {
        $header = "Import-Module -Force $PSScriptRoot\..\util"
        Set-Content $tempScript.FullName "$header; $Expr"
        return Invoke-Expression "$Exe -File $tempScript"
    } finally {
        Remove-Item -Force $tempScript
    }
}
