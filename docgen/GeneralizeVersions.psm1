using namespace System.Management.Automation

Set-StrictMode -Version Latest
$script:ErrorActionPreference = "Stop"

[Object] $script:RootValue = ""

function ValuesEqual {
    [CmdletBinding()]
    [OutputType([Bool])]
    param(
        [Parameter(Mandatory)]
        [Object] $Value1,
        [Parameter(Mandatory)]
        [Object] $Value2
    )

    return $Value1.ToString() -eq $Value2.ToString()
}

function IsValueRoot {
    [CmdletBinding()]
    [OutputType([Bool])]
    param(
        [Parameter(Mandatory)]
        [Object] $Value
    )

    return ValuesEqual $Value $script:RootValue
}

function GetRest {
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory)]
        [Object[]] $List # oooh, it's generic!
    )

    return $List.Count -gt 1 ?
        $List[1..($List.Count - 1)] :
        ,@()
}

class VersionNode {
    [VersionNode[]] hidden $Children
    [Object] hidden $Value
    [String] hidden $GeneralizeSuffix
    [Boolean] hidden $IsLeafInSubset

    VersionNode() {
        $this.Children = @()
        $this.Value = $script:RootValue
        $this.GeneralizeSuffix = ""
        $this.IsLeafInSubset = $false
    }

    VersionNode([Object] $Value, [String] $GeneralizeSuffix) {
        $this.Children = @()
        $this.Value = $Value
        $this.GeneralizeSuffix = $GeneralizeSuffix
        $this.IsLeafInSubset = $false
    }

    [Void] AddNodesBelow([Tuple`2[[Object], [String]][]] $Values) {
        if ($Values.Count -gt 0) {
            [Tuple`2[[Object], [String]]] $first = $Values[0]
            [Tuple`2[[Object], [String]][]] $rest = GetRest $Values

            foreach ($child in $this.Children) {
                if (ValuesEqual $child.Value $first.Item1) {
                    $child.AddNodesBelow($rest)
                    return
                }
            }

            [VersionNode] $newChild = [VersionNode]::new($first.Item1, $first.Item2)
            $newChild.AddNodesBelow($rest)
            $this.Children += $newChild
        }
    }

    [Void] MarkLeaf([Object[]] $Values) {
        if (ValuesEqual $Values[0] $this.Value) {
            [Object[]] $rest = GetRest $Values

            if ($rest.Count -eq 0) {
                $this.IsLeafInSubset = $true
            } else {
                foreach ($child in $this.Children) {
                    $child.MarkLeaf($rest)
                }
            }
        }
    }

    [Tuple`2[[String[]], [Boolean]]] Generalize() {
        if ($this.Children.Count -eq 0) {
            if ($this.IsLeafInSubset) {
                return [Tuple]::Create([String[]] @($this.Value.ToString()), $true)
            } else {
                return [Tuple]::Create([String[]] @(), $false)
            }
        } else {
            [String[]] $childResults = @()
            [Byte] $numChildrenFullyCovered = 0

            foreach ($child in $this.Children) {
                [Tuple`2[[String[]], [Boolean]]] $result = $child.Generalize()

                if ($null -ne $result.Item1 -and $result.Item1.Count -gt 0) {
                    $childResults += $result.Item1
                }

                if ($result.Item2) {
                    $numChildrenFullyCovered += 1
                }
            }

            [String] $prefix = (IsValueRoot $this.Value) ? "" : "$($this.Value)."
            if ($numChildrenFullyCovered -eq $this.Children.Count) {
                [String[]] $strings = $this.GeneralizeSuffix -ne "" ? @("$prefix$($this.GeneralizeSuffix)") : $childResults
                return [Tuple]::Create([String[]] $strings, $true)
            } else {
                [String[]] $strings = $childResults | ForEach-Object { "$prefix$_" }
                return [Tuple]::Create([String[]] $strings, $false)
            }
        }
    }

    [String] ToString() {
        [String] $stringValue = (IsValueRoot $this.Value) ? "root" : $this.Value.ToString()

        if ($this.Children.Count -eq 0) {
            [String] $mark = $this.IsLeafInSubset ? "*" : ""
            return "$stringValue$mark"
        } else {
            [String[]] $childStrings = $this.Children | ForEach-Object { $_.ToString() }
            [String] $childStringsCombined = $childStrings -join " "
            return "($stringValue $childStringsCombined)"
        }
    }
}

class VersionTree {
    [VersionNode] hidden $Root

    VersionTree() {
        $this.Root = [VersionNode]::new()
    }

    [Void] Add([SemanticVersion] $Version) {
        [Tuple`2[[Object], [String]][]] $nodeValues = @(
            [Tuple]::Create([Object] $Version.Major, "x"),
            [Tuple]::Create([Object] $Version.Minor, "y"),
            [Tuple]::Create([Object] $Version.Patch, "")
        )
        $this.Root.AddNodesBelow($nodeValues)
    }

    [Void] MarkVersion([SemanticVersion] $Version) {
        [Object[]] $nodeValues = @(
            $script:RootValue,
            $Version.Major,
            $Version.Minor,
            $Version.Patch
        )
        $this.Root.MarkLeaf($nodeValues)
    }

    [String[]] Generalize() {
        return $this.Root.Generalize().Item1
    }

    [String] ToString() {
        return $this.Root.ToString()
    }
}

function GeneralizeVersions {
    [CmdletBinding()]
    [OutputType([String[]])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion[]] $AllVersions,
        [Parameter(Mandatory)]
        [SemanticVersion[]] $VersionSubset
    )

    [VersionTree] $tree = [VersionTree]::new()
    foreach ($version in $AllVersions) {
        $tree.Add($version)
    }

    foreach ($version in $VersionSubset) {
        $tree.MarkVersion($version)
    }

    [String[]] $generalizations = $tree.Generalize()
    [String[]] $filtered = $generalizations | ForEach-Object { $_ -replace ".0`$", "" }
    return $filtered
}
