function RunPowerShellExe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('PwshExe')]
        [PSCustomObject] $Exe,
        [Parameter(Mandatory)]
        [String] $CodeToRun
    )

    Write-Host "Running $($Exe.File) $($Exe.InitialArgs)"

    return InvokeExe $Exe $CodeToRun
}

function GroupVersionsByOutput {
    [CmdletBinding()]
    [OutputType([Dictionary[String, SemanticVersion[]]])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs,
        [Parameter(Mandatory)]
        [ScriptBlock] $StreamGetter
    )

    [Dictionary[String, SemanticVersion[]]] $streamMap = [Dictionary[String, SemanticVersion[]]]::new()
    foreach ($output in $Outputs) {
        [String] $streamString = & $StreamGetter $output

        if (-not $streamMap.ContainsKey($streamString)) {
            $streamMap[$streamString] = @()
        }

        $streamMap[$streamString] += $output.Version
    }

    return $streamMap
}

function GetOutputs {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $MinVersion,
        [Parameter(Mandatory)]
        [String] $Code
    )

    [PSCustomObject[]] $exesToTest = GetPowerShellExesToTest $MinVersion

    return $exesToTest | ForEach-Object -ThrottleLimit 8 -Parallel {
        [PSCustomObject] $exe = $_

        [PSModuleInfo] $docgen = Import-Module "$using:PSScriptRoot\..\docgen" -Force -PassThru
        # Run in the context of the docgen module
        return & $docgen { RunPowerShellExe $exe $using:Code }
    }
}

function FormatOutputStream {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $StreamString
    )

    return "<pre class=`"output-text`">$(EscapeHtml $StreamString)</pre>"
}

function HasOutput {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param(
        [Parameter(Mandatory)]
        [Dictionary[String, SemanticVersion[]]] $StreamMap
    )

    [Boolean] $noOutut = ($StreamMap.Count -eq 0) -or (($StreamMap.Count -eq 1) -and ($StreamMap.ContainsKey('')))
    return -not $noOutut
}

function GetStreamViewHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion[]] $AllVersions,
        [Parameter(Mandatory)]
        [Dictionary[String, SemanticVersion[]]] $StreamMap,
        [Parameter(Mandatory)]
        [String] $StreamName
    )

    if (-not (HasOutput $StreamMap)) {
        return ''
    }

    # Create a map of stream string to generalized version string.
    [Dictionary[String, String]] $generalizedMap = [Dictionary[String, String]]::new()
    foreach ($streamString in $streamMap.Keys) {
        [SemanticVersion[]] $versionList = $streamMap[$streamString]
        [String[]] $sortedVersions = GeneralizeVersions $AllVersions $versionList | Sort-Object
        $generalizedMap[$streamString] = $sortedVersions -join ', '
    }

    [String[]] $sortedKeys = $generalizedMap.Keys | `
        Sort-Object @{ Expression = { $generalizedMap[$_] } }

    [String[]] $versionSections = @()
    foreach ($streamString in $sortedKeys) {
            [String] $versionString = $generalizedMap[$streamString]
            [String] $versionGroupId = (New-Guid).Guid
            $versionSections += @"
                <div class=`"stream-view-flex-item`">
                    <div class=`"output-view-heading`" id=`"$versionGroupId`">$versionString</div>
                    <div aria-labelledby=`"$versionGroupId`">
                        $(FormatOutputStream $streamString)
                    </div>
                </div>
"@
    }

    [String] $streamId = (New-Guid).Guid
    return @"
        <div class=`"stream-view`">
            <div class =`"output-view-heading`" id=`"$streamId`">$StreamName</div>
            <div class=`"stream-view-scroll`" aria-labelledby=`"$streamId`">
                <div>
                    $versionSections
                </div>
            </div>
        </div>
"@
}

function GetOutputTableHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs
    )

    # Create maps of stdout/stderr strings to list of versions. This lets us
    # group versions by what their output is.
    [Dictionary[String, SemanticVersion[]]] $stdoutMap = GroupVersionsByOutput $Outputs { $args[0].Stdout }
    [Dictionary[String, SemanticVersion[]]] $stderrMap = GroupVersionsByOutput $Outputs { $args[0].Stderr }

    [SemanticVersion[]] $allVersions = $outputs | ForEach-Object { $_.Version }

    if ((-not (HasOutput $stdoutMap)) -and (-not (HasOutput $stderrMap))) {
        return ''
    } else {
        [String] $stdoutView = GetStreamViewHtml $allVersions $stdoutMap 'Stdout'
        [String] $stderrView = GetStreamViewHtml $allVersions $stderrMap 'Stderr'
        return $stdoutView + $stderrView
    }
}

function BuildRawOutputView {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs
    )

    [String] $html = '<details><summary>Raw output</summary><div class="raw-output-view">'

    [String] $outputTableHtml = GetOutputTableHtml $Outputs
    if ($outputTableHtml.Length -eq 0) {
        $html += '<p>No output</p>'
    } else {
        $html += $outputTableHtml
    }

    $html += '</div></details>'

    return $html
}

function MarkCodeLines {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Code
    )

    [String[]] $lines = $Code -split "`n"
    [String[]] $wrappedLines = $lines | ForEach-Object {
        "<li><span class=`"line-number`" aria-hidden=`"true`"></span>$_</li>"
    }

    return $wrappedLines -join ''
}

function BuildCodeHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Code
    )

    [String] $formattedCode = EscapeHtml (FormatPageText $Code)
    [String] $lined = MarkCodeLines $formattedCode
    return "<pre class=`"code-view`"><code class=`"powershell`"><ol>$lined</ol></code></pre>"
}

function GetSingleLineHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $LineText,
        [Parameter(Mandatory)]
        [UInt32] $LineNumber
    )

    [String] $lineHtml = "<span class=`"line-number`" aria-label=`"Line $LineNumber`">$LineNumber</span>$LineText"
    return "<pre class=`"code-view`"><code class=`"powershell`">$lineHtml</code></pre>"
}

function BuildOutputView {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs,
        [Parameter(Mandatory)]
        [String] $Code
    )

    [String] $html = '<div class="output-view">'

    [String[]] $codeLines = $Code -split "`n"
    foreach ($lineNumber in 1..$codeLines.Count) {
        [PSCustomObject[]] $outputsForLine = @()
        foreach ($output in $Outputs) {
            [PSCustomObject[]] $lines = $output.GetLines($lineNumber)
            if ($lines.Count -gt 0) {
                $outputsForLine += NewExampleOutput $output.Version $lines
            }
        }

        if ($outputsForLine.Count -gt 0) {
            [String] $outputTableHtml = GetOutputTableHtml $outputsForLine
            if ($outputTableHtml.Length -gt 0) {
                [String] $lineText = $codeLines[$lineNumber - 1]
                $html += GetSingleLineHtml $lineText $lineNumber
                $html += $outputTableHtml
            }
        }
    }

    $html += '</div>'

    return $html
}

function OutputCode {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $Code,
        [String] $MinVersion = "0"
    )

    if ($script:buildingOutline) {
        return
    }

    [SemanticVersion] $minVersionSemantic = [SemanticVersion]::new($MinVersion)

    [String] $codeAsString = FormatPageText $Code.ToString()
    [PSCustomObject[]] $outputs = GetOutputs $minVersionSemantic $codeAsString

    [String] $codeHtml = BuildCodeHtml $codeAsString
    [String] $outputView = BuildOutputView $outputs $codeAsString
    [String] $rawOutputHtml = BuildRawOutputView $outputs

    return $codeHtml + $outputView + $rawOutputHtml
}
