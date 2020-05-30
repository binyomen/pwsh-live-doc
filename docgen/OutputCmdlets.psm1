using namespace System.IO
using namespace System.Management.Automation

function GetIndent {
    [CmdletBinding()]
    [OutputType([Byte])]
    param(
        [Parameter(Mandatory)]
        [String] $Line
    )

    [Byte] $indent = 0
    foreach ($char in $line.ToCharArray()) {
        if ($char -ne " ") {
            break
        }
        $indent += 1
    }
    return $indent
}

function FormatPageText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    [String] $normalizedText = $Text -replace "`r", ""
    [String[]] $lines = $normalizedText -split "`n"

    # Remove any blank leading or ending lines.
    while ($lines.Length -gt 0) {
        if ($lines[0].Trim().Length -gt 0) {
            break
        }
        $lines = $lines[1..($lines.Length - 1)]
    }
    while ($lines.Length -gt 0) {
        if ($lines[$lines.Length - 1].Trim().Length -gt 0) {
            break
        }
        $lines = $lines[0..($lines.Length - 2)]
    }

    [Byte] $minIndent = ($lines |`
        Where-Object { $_.Length -gt 0 } |`
        ForEach-Object { GetIndent $_ } |`
        Measure-Object -Minimum).Minimum
    [String[]] $deindentedLines = $lines | ForEach-Object { $_[$minIndent..($_.Length - 1)] -join "" }

    [String] $formattedText = $deindentedLines -join "`n"
    return $formattedText
}

function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    $formattedText = FormatPageText $Text
    return (ConvertFrom-Markdown -InputObject $formattedText).Html
}

function OutputCode {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $Code
    )

    $codeAsString = $Code.ToString()
    $formattedCode = FormatPageText $codeAsString
    $codeHtml = "<pre class=`"code-view`"><code class=`"powershell`">" + $formattedCode + "</code></pre>"

    $outputTableHtml = "<table class=`"output-table`"><caption>Output by version</caption><thead><tr>"

    $exesToTest = GetPowerShellExesToTest

    # Create a map of output string to list of versions. This lets us group
    # versions by what their output is.
    $outputToVersionMap = @{}
    $allVersions = @()
    foreach ($exe in $exesToTest) {
        Write-Host "Running $exe"

        $commandOutput = InvokeExe $exe $Code.ToString()
        $formattedCommandOutput = "<pre class=`"output-text`">" + $commandOutput + "</pre>"

        if (-not $outputToVersionMap.ContainsKey($formattedCommandOutput)) {
            $outputToVersionMap[$formattedCommandOutput] = @()
        }

        $version = GetExeVersion $exe
        $outputToVersionMap[$formattedCommandOutput] += $version
        $allVersions += $version
    }

    # Now create a map from version string to corresponding output. This lets
    # us sort the version strings without mismatching them with their outputs.
    $versionStringToOutputMap = @{}
    foreach ($output in $outputToVersionMap.Keys) {
        $generalizedVersions = GeneralizeVersions $allVersions $outputToVersionMap[$output] | Sort-Object
        $versionStringToOutputMap["<th>$($generalizedVersions -join ", ")</th>"] = $output
    }

    $sortedVersionKeys = $versionStringToOutputMap.Keys | Sort-Object
    $outputTableHtml += "$sortedVersionKeys"

    $outputTableHtml += "</tr></thead><tbody><tr>"

    foreach ($version in $sortedVersionKeys) {
        $output = $versionStringToOutputMap[$version]
        $outputTableHtml += "<td>$output</td>"
    }

    $outputTableHtml += "</tr></tbody></table>"

    return $codeHtml + $outputTableHtml
}

function OutputPage {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [FileInfo] $PageModuleFile
    )

    Import-Module $PageModuleFile -Force

    $title = GetTitle
    Write-Host
    Write-Host "============$($PageModuleFile.Name)============"
    Write-Host "Generating page for '$title'"
    $pageHtml = (RunPage) -join "`n"
    Write-Host "==========================================="

    return "<section><h2>$title</h2>$pageHtml</section>"
}
