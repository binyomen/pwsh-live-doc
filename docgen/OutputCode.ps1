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

function BuildOutputView {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $Code,
        [Parameter(Mandatory)]
        [SemanticVersion] $MinVersion
    )

    [String] $html = "<div class=`"output-view`">"

    [PSCustomObject[]] $outputs = GetOutputs $minVersionSemantic $codeAsString

    # Create maps of stdout/stderr strings to list of versions. This lets us
    # group versions by what their output is.
    [Dictionary[String, SemanticVersion[]]] $stdoutMap = GroupVersionsByOutput $outputs { $args[0].Stdout }
    [Dictionary[String, SemanticVersion[]]] $stderrMap = GroupVersionsByOutput $outputs { $args[0].Stderr }

    [SemanticVersion[]] $allVersions = $outputs | ForEach-Object { $_.Version }

    if ((-not (HasOutput $stdoutMap)) -and (-not (HasOutput $stderrMap))) {
        $html += '<p>No output</p>'
    } else {
        $html += GetStreamViewHtml $allVersions $stdoutMap 'Stdout'
        $html += GetStreamViewHtml $allVersions $stderrMap 'Stderr'
    }

    $html += "</div>"

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
