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
        [ScriptBlock] $ContentGetter
    )

    [Dictionary[String, SemanticVersion[]]] $outputMap = [Dictionary[String, SemanticVersion[]]]::new()
    foreach ($output in $Outputs) {
        [String] $outputContent = & $ContentGetter $output

        if (-not $outputMap.ContainsKey($outputContent)) {
            $outputMap[$outputContent] = @()
        }

        $outputMap[$outputContent] += $output.Version
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

    return "<pre><samp>$(EscapeHtml $StreamString)</samp></pre>"
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

    [String] $tablist = '<div role="tablist" class="tablist-hidden">'
    [String] $tabpanels = ''
    foreach ($streamString in $sortedKeys) {
        [String] $tabId = (New-Guid).Guid
        [String] $versionString = $generalizedMap[$streamString]

        [String] $tabpanelId = (New-Guid).Guid
        [String] $formattedStream = FormatOutputStream $streamString
        [String] $noScriptHeading = "<noscript><div aria-hidden=`"true`">$versionString</div></noscript>"

        $tablist += "<button id=`"$tabId`" role=`"tab`" aria-controls=`"$tabpanelId`">$versionString</button>"
        $tabpanels += "$noScriptHeading<div id=`"$tabpanelId`" role=`"tabpanel`" aria-labelledby=`"$tabId`">$formattedStream</div>"
    }
    $tablist += '</div>'

    [String] $streamId = (New-Guid).Guid
    return @"
        <div class=`"stream-view`">
            <div class =`"stream-view-heading`" id=`"$streamId`">$StreamName</div>
            <div aria-labelledby=`"$streamId`">
                $tablist
                <div class=`"tabpanel-container`">
                    $tabpanels
                </div>
            </div>
        </div>
"@
}

function GetOutputViewHtml {
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

    [String] $stdoutView = GetStreamViewHtml $allVersions $stdoutMap 'Stdout'
    [String] $stderrView = GetStreamViewHtml $allVersions $stderrMap 'Stderr'
    return $stdoutView + $stderrView
}

function BuildOutputView {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('ExampleOutput')]
        [PSCustomObject[]] $Outputs
    )

    return "<div class=`"output-view`">$(GetOutputViewHtml $Outputs)</div>"
}

function BuildCodeHtml {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Code
    )

    # Use hljs so we get syntax highlighting background. This can be removed
    # once we do syntax highlighting at compile time.
    [String] $html = '<div class="code-view hljs"><ol>'

    [String[]] $lines = $Code -split "`n"
    foreach ($line in $lines) {
        $html += "<li>$(GetSingleLineHtml $line)</li>"
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
        [String] $Line
    )

    return `
        "<pre><code class=`"powershell`">" +
            "<span class=`"line-number`" aria-hidden=`"true`"></span>$Line" +
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

    [String] $codeAsString = $Code.ToString()
    [PSCustomObject[]] $outputs = GetOutputs $minVersionSemantic $codeAsString

    [String] $codeHtml = BuildCodeHtml (EscapeHtml (FormatPageText $codeAsString))
    [String] $rawOutputHtml = BuildOutputView $outputs

    return $codeHtml + $rawOutputHtml
}
