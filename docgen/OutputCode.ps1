[String] $script:outputLinePrefix = '<span class="output-line">'
[String] $script:outputLineSuffix = '</span>'

function RunPowerShellExe {
    [CmdletBinding()]
    [OutputType([Tuple[SemanticVersion, PSCustomObject][]])]
    param(
        [Parameter(Mandatory)]
        [Tuple[[String[]], SemanticVersion]] $Tuple,
        [Parameter(Mandatory)]
        [String] $CodeToRun
    )

    Write-Host "Running $($Tuple.Item1)"

    [PSCustomObject] $output = InvokeExe $Tuple.Item1 $CodeToRun
    return [Tuple]::Create($Tuple.Item2, $output)
}

function FoldOutput {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Output
    )

    [String[]] $lines = $Output -split "`n"
    [String[][]] $groups = @()

    # Collapse stack traces
    [String[]] $currentGroup = @()
    [String[]] $blankLines = @()
    foreach ($line in $lines) {
        if ($line -match "$script:outputLinePrefix\s*(At |\+)") {
            $currentGroup += $line
            $currentGroup += $blankLines
            $blankLines = @()
        } elseif ($line -match "$script:outputLinePrefix\s*$script:outputLineSuffix") {
            $blankLines += $line
            if ($currentGroup.Count -gt 1) {
                $currentGroup += $blankLines
                $blankLines = @()
            }
        } else {
            if ($currentGroup.Count -gt 0) {
                $groups += ,$currentGroup
                foreach ($blankLine in $blankLines) {
                    $groups += ,$blankLine
                }
                $blankLines = @()
                $currentGroup = @()
            }

            $currentGroup += $line
        }
    }
    if ($currentGroup.Count -gt 0) {
        $groups += ,$currentGroup
    }

    [String] $html = ''
    foreach ($group in $groups) {
        if ($group.Count -gt 1) {
            [String] $groupedLines = $group[1..($group.Count - 1)] -join "`n"
            $html += "<details><summary>$($group[0])</summary>$groupedLines</details>"
        } else {
            $html += $group[0] + "`n"
        }
    }

    return $html
}

function GetOutputToVersionMap {
    [CmdletBinding()]
    [OutputType([Dictionary[String, SemanticVersion[]]])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $MinVersion,
        [Parameter(Mandatory)]
        [String] $Code
    )

    [Tuple[[String[]], SemanticVersion][]] $exesToTest = GetPowerShellExesToTest $MinVersion

    [Tuple[SemanticVersion, PSCustomObject][]] $powershellResults = $exesToTest | ForEach-Object -ThrottleLimit 8 -Parallel {
        [Tuple[[String[]], System.Management.Automation.SemanticVersion]] $tuple = $_

        [PSModuleInfo] $docgen = Import-Module "$using:PSScriptRoot\..\docgen" -Force -PassThru
        # Run in the context of the docgen module
        return & $docgen { RunPowerShellExe $tuple $using:Code }
    }

    [Dictionary[String, SemanticVersion[]]] $outputToVersionMap = [Dictionary[String, SemanticVersion[]]]::new()
    foreach ($tuple in $powershellResults) {
        [SemanticVersion] $version = $tuple.Item1
        [String] $output = ConvertTo-Json $tuple.Item2

        if (-not $outputToVersionMap.ContainsKey($output)) {
            $outputToVersionMap[$output] = @()
        }

        $outputToVersionMap[$output] += $version
    }

    return $outputToVersionMap
}

function MarkLines {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    [String[]] $lines = $Text -split "`n"
    [String[]] $markedLines = $lines | ForEach-Object { "$script:outputLinePrefix$_$script:outputLineSuffix" }

    return $markedLines -join "`n"
}

function FormatOutputStream {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Stream,
        [Parameter(Mandatory)]
        [String] $StreamName
    )

    [String] $html = ''

    if ($Stream.Length -gt 0) {
        [String] $escaped = EscapeHtml $Stream
        [String] $linesMarked = MarkLines $escaped
        [String] $folded = FoldOutput $linesMarked

        [String] $streamId = (New-Guid).Guid
        $html += "<div class=`"output-view-heading`" id=`"$streamId`">$StreamName</div>"
        $html += "<pre class=`"output-text`" aria-labelledby=`"$streamId`">$folded</pre>"
    }

    return $html
}

function BuildOutputView {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $Code,
        [Parameter(Mandatory)]
        [SemanticVersion] $MinVersion
    )

    [String] $html = '<div class="output-view">'

    [String] $topLevelId = (New-Guid).Guid
    $html += "<div class=`"output-view-heading`" id=`"$topLevelId`">Output by version</div>"
    $html += "<div class=`"output-view-flex`" aria-labelledby=`"$topLevelId`">"

    # Create a map of output string to list of versions. This lets us group
    # versions by what their output is.
    [Dictionary[String, SemanticVersion[]]] $outputToVersionMap = GetOutputToVersionMap $minVersionSemantic $codeAsString

    [SemanticVersion[]] $allVersions = $outputToVersionMap.Values | `
        ForEach-Object { [SemanticVersion[]] $all = @() } { $all = $all + $_ | Select-Object -Unique } { $all }

    # Create a map of output string to generalized version string.
    [Dictionary[String, String]] $outputToGeneralizedVersionMap = [Dictionary[String, String]]::new()
    foreach ($outputJson in $outputToVersionMap.Keys) {
        [SemanticVersion[]] $versionList = $outputToVersionMap[$outputJson]
        [String[]] $sortedVersions = GeneralizeVersions $allVersions $versionList | Sort-Object
        $outputToGeneralizedVersionMap[$outputJson] = $sortedVersions -join ', '
    }
    [String[]] $sortedKeys = $outputToGeneralizedVersionMap.Keys | `
        Sort-Object @{ Expression = { $outputToGeneralizedVersionMap[$_] } }

    [String[]] $versionSections = @()
    foreach ($outputJson in $sortedKeys) {
            [PSCustomObject] $output = ConvertFrom-Json $outputJson
            [String] $versionString = $outputToGeneralizedVersionMap[$outputJson]

            [String] $versionGroupId = (New-Guid).Guid
            $versionSections += @"
                <div>
                    <div class=`"output-view-heading`" id=`"$versionGroupId`">$versionString</div>
                    <div aria-labelledby=`"$versionGroupId`">
                        $(FormatOutputStream $output.Stdout 'stdout')
                        $(FormatOutputStream $output.Stderr 'stderr')
                    </div>
                </div>
"@
    }

    $html += $versionSections -join "`n"
    $html += "</div></div>"

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

    [String] $codeAsString = $Code.ToString()
    [String] $formattedCode = EscapeHtml (FormatPageText $codeAsString)
    [String] $codeHtml = '<pre class="code-view"><code class="powershell">' + $formattedCode + '</code></pre>'

    return $codeHtml + (BuildOutputView $Code $minVersionSemantic)
}
