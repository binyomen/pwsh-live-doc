using namespace System.Management.Automation

class VersionNode {
    [VersionNode[]] hidden $Children
    [Object] hidden $Value
    [String] hidden $GeneralizeSuffix
    [Boolean] hidden $IsLeafInSubset

    VersionNode() {
        $this.Children = @()
        $this.Value = $null
        $this.GeneralizeSuffix = "all versions"
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
            $first = $Values[0]
            $rest = $Values[1..$Values.Count]

            foreach ($child in $this.Children) {
                if ($child.Value -eq $first.Item1) {
                    $child.AddNodesBelow($rest)
                    return
                }
            }

            $newChild = [VersionNode]::new($first.Item1, $first.Item2)
            $newChild.AddNodesBelow($rest)
            $this.Children += $newChild
        }
    }

    [Void] MarkLeaf([Object[]] $Values) {
        if ($Values[0] -eq $this.Value) {
            $rest = $Values[1..$Values.Count]

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
            $childResults = @()
            $numChildrenFullyCovered = 0

            foreach ($child in $this.Children) {
                $result = $child.Generalize()

                if ($result.Item1.Count -gt 0) {
                    $childResults += $result.Item1
                }

                if ($result.Item2) {
                    $numChildrenFullyCovered += 1
                }
            }

            $prefix = $this.Value -ne $null ? "$($this.Value)." : ""
            if ($numChildrenFullyCovered -eq $this.Children.Count) {
                $strings = $this.Value -ne $null ? "$prefix$($this.GeneralizeSuffix)" : @()
                return [Tuple]::Create([String[]] $strings, $true)
            } else {
                $strings = $childResults | ForEach-Object { "$prefix$_" }
                return [Tuple]::Create([String[]] $strings, $false)
            }
        }
    }

    [String] ToString() {
        $stringValue = ($this.Value ?? "root").ToString()

        if ($this.Children.Count -eq 0) {
            $mark = $this.IsLeafInSubset ? "*" : ""
            return "$stringValue$mark"
        } else {
            $childStrings = $this.Children | ForEach-Object { $_.ToString() }
            $childStringsCombined = $childStrings -join " "
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
        $nodeValues = @(
            [Tuple]::Create([Object] $Version.Major, "x"),
            [Tuple]::Create([Object] $Version.Minor, "y"),
            [Tuple]::Create([Object] $Version.Patch, "")
        )
        $this.Root.AddNodesBelow($nodeValues)
    }

    [Void] MarkVersion([SemanticVersion] $Version) {
        $nodeValues = @(
            $null,
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

    $tree = [VersionTree]::new()
    foreach ($version in $AllVersions) {
        $tree.Add($version)
    }

    foreach ($version in $VersionSubset) {
        $tree.MarkVersion($version)
    }

    $generalizations = $tree.Generalize()
    $filtered = $generalizations | ForEach-Object { $_ -replace ".0`$", "" }
    return $filtered
}
