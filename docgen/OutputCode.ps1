[String] $script:startsLineMarker = '{{START}}'
[String] $script:endsLineMarker = '{{END}}'

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
        [AllowEmptyCollection()]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs,
        [Parameter(Mandatory)]
        [ScriptBlock] $ContentGetter,
        [Parameter(Mandatory)]
        [ScriptBlock] $StartsLineGetter,
        [Parameter(Mandatory)]
        [ScriptBlock] $EndsLineGetter
    )

    [Dictionary[String, SemanticVersion[]]] $outputMap = [Dictionary[String, SemanticVersion[]]]::new()
    foreach ($output in $Outputs) {
        [String] $outputContent = & $ContentGetter $output
        [Boolean] $startsLine = & $StartsLineGetter $output
        [Boolean] $endsLine = & $EndsLineGetter $output

        [String] $key = ''
        if ($startsLine) {
            $key += $script:startsLineMarker
        }
        $key += $outputContent
        if ($endsLine) {
            $key += $script:endsLineMarker
        }

        if (-not $outputMap.ContainsKey($key)) {
            $outputMap[$key] = @()
        }

        $outputMap[$key] += $output.Version
    }

    return $outputMap
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

    if ($StreamString.Length -gt 0) {
        [String] $content = $StreamString

        [String] $prefix = '<aside>[does not start line]</aside>'
        if ($content.StartsWith($script:startsLineMarker)) {
            $prefix = ''
            $content = $content.Substring($script:startsLineMarker.Length)
        }

        [String] $suffix = '<aside>[does not end line]</aside>'
        if ($content.EndsWith($script:endsLineMarker)) {
            $suffix = ''
            [UInt32] $finalLength = $content.Length - $script:endsLineMarker.Length
            $content = $content.Substring(0, $finalLength)
        }

        return "$prefix<pre class=`"output-text`"><samp>$(EscapeHtml $content)</samp></pre>$suffix"
    } else {
        return '<p>No output</p>'
    }
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
        [String] $StreamName,

        [Switch] $KeepEmptyOutputs
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

    [String] $tablist = '<div role="tablist" class="tablist-hidden">'
    [String] $tabpanels = ''
    foreach ($streamString in $sortedKeys) {
        if ($KeepEmptyOutputs -or ($streamString.Length -gt 0)) {
            [String] $tabId = (New-Guid).Guid
            [String] $versionString = $generalizedMap[$streamString]

            [String] $tabpanelId = (New-Guid).Guid
            [String] $formattedStream = FormatOutputStream $streamString
            [String] $noScriptHeading = "<noscript><div aria-hidden=`"true`">$versionString</div></noscript>"

            $tablist += "<button id=`"$tabId`" role=`"tab`" aria-controls=`"$tabpanelId`">$versionString</button>"
            $tabpanels += "$noScriptHeading<div id=`"$tabpanelId`" role=`"tabpanel`" tabindex=`"0`" aria-labelledby=`"$tabId`">$formattedStream</div>"
        }
    }
    $tablist += '</div>'

    [String] $streamId = (New-Guid).Guid
    return @"
        <div class=`"stream-view`">
            <div class =`"output-view-heading`" id=`"$streamId`">$StreamName</div>
            <div aria-labelledby=`"$streamId`">
                $tablist
                <div class=`"tabpanel-container`">
                    $tabpanels
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
        [AllowEmptyCollection()]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs,

        [Switch] $KeepEmptyOutputs
    )

    # Create maps of stdout/stderr strings to list of versions. This lets us
    # group versions by what their output is.
    [Dictionary[String, SemanticVersion[]]] $stdoutMap = `
        GroupVersionsByOutput $Outputs { $args[0].Stdout } { $args[0].StdoutStartsLine } { $args[0].StdoutEndsLine }
    [Dictionary[String, SemanticVersion[]]] $stderrMap = `
        GroupVersionsByOutput $Outputs { $args[0].Stderr } { $args[0].StderrStartsLine } { $args[0].StderrEndsLine }

    [SemanticVersion[]] $allVersions = $outputs | ForEach-Object { $_.Version }

    if ((-not (HasOutput $stdoutMap)) -and (-not (HasOutput $stderrMap))) {
        return ''
    } else {
        [String] $stdoutView = GetStreamViewHtml $allVersions $stdoutMap 'Stdout' -KeepEmptyOutputs:$KeepEmptyOutputs
        [String] $stderrView = GetStreamViewHtml $allVersions $stderrMap 'Stderr' -KeepEmptyOutputs:$KeepEmptyOutputs
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

    [String] $html = '<div class="raw-output-view"><details><summary>Raw output</summary>'

    [String] $outputTableHtml = GetOutputTableHtml $Outputs -KeepEmptyOutputs
    if ($outputTableHtml.Length -eq 0) {
        $html += '<p>No output</p>'
    } else {
        $html += $outputTableHtml
    }

    $html += '</details></div>'

    return $html
}

function BuildCodeHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Code,
        [Parameter(Mandatory)]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs
    )

    [String] $html = '<div class="code-view"><ol>'

    [String[]] $codeLines = $Code -split "`n"
    foreach ($lineNumber in 1..$codeLines.Count) {
        [PSCustomObject[]] $outputsForLine = @()
        foreach ($output in $Outputs) {
            [PSCustomObject[]] $lines = $output.GetLines($lineNumber)
            if ($lines.Count -gt 0) {
                $outputsForLine += NewExampleOutput $output.Version $lines
            }
        }

        [String] $lineText = $codeLines[$lineNumber - 1]
        [String] $outputTableHtml = GetOutputTableHtml $outputsForLine
        [String] $lineHtml = GetSingleLineHtml $lineText
        if ($outputTableHtml.Length -gt 0) {
            [String] $lineId = (New-Guid).Guid
            [String] $expandIcon = '<div aria-label="expand icon"></div>'
            $html += "<li aria-labelledby=`"$lineId`"><details><summary id=`"$lineId`" class=`"line-grid`">$expandIcon$lineHtml</summary>$outputTableHtml</details></li>"
        } else {
            $html += "<li class=`"line-grid`"><span></span>$lineHtml</li>"
        }
    }

    $html += '</ol></div>'

    return $html
}

function GetSingleLineHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $LineText
    )

    return `
        "<pre><code class=`"powershell`">" +
            "<span class=`"line-number`" aria-hidden=`"true`"></span>$LineText" +
        "</code></pre>"
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

    [String] $codeHtml = BuildCodeHtml (EscapeHtml $codeAsString) $outputs
    [String] $rawOutputHtml = BuildRawOutputView $outputs

    return $codeHtml + $rawOutputHtml
}
