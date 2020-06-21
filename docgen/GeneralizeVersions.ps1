# Needed for types in classes below.
using namespace System.Management.Automation

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

#region VersionNode

function NewRootVersionNode {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        PSTypeName = 'VersionNode'
        Children = @()
        Value = $script:RootValue
        GeneralizeSuffix = ""
        IsLeafInSubset = $false
    }
}

function NewChildVersionNode {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Object] $Value,
        [String] $GeneralizeSuffix
    )

    return [PSCustomObject]@{
        PSTypeName = 'VersionNode'
        Children = @()
        Value = $Value
        GeneralizeSuffix = $GeneralizeSuffix
        IsLeafInSubset = $false
    }
}

AddScriptMethod VersionNode AddNodesBelow {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [Tuple[Object, String][]] $Values
    )

    if ($Values.Count -gt 0) {
        [Tuple[Object, String]] $first = $Values[0]
        [Tuple[Object, String][]] $rest = GetRest $Values

        foreach ($child in $this.Children) {
            if (ValuesEqual $child.Value $first.Item1) {
                $child.AddNodesBelow($rest)
                return
            }
        }

        [PSCustomObject] $newChild = NewChildVersionNode $first.Item1 $first.Item2
        $newChild.AddNodesBelow($rest)
        $this.Children += $newChild
    }
}

AddScriptMethod VersionNode MarkLeaf {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [Object[]] $Values
    )

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

AddScriptMethod VersionNode Generalize {
    [CmdletBinding()]
    [OutputType([Tuple[[String[]], Boolean]])]
    param()

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
            [Tuple[[String[]], Boolean]] $result = $child.Generalize()

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

AddScriptMethod VersionNode ToString {
    [CmdletBinding()]
    [OutputType([String])]
    param()

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

#endregion

#region VersionTree

function NewVersionTree {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        PSTypeName = 'VersionTree'
        Root = NewRootVersionNode
    }
}

AddScriptMethod VersionTree Add {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $Version
    )

    [Tuple[Object, String][]] $nodeValues = @(
        [Tuple]::Create([Object] $Version.Major, "x"),
        [Tuple]::Create([Object] $Version.Minor, "y"),
        [Tuple]::Create([Object] $Version.Patch, "")
    )
    $this.Root.AddNodesBelow($nodeValues)
}

AddScriptMethod VersionTree MarkVersion {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $Version
    )

    [Object[]] $nodeValues = @(
        $script:RootValue,
        $Version.Major,
        $Version.Minor,
        $Version.Patch
    )
    $this.Root.MarkLeaf($nodeValues)
}

AddScriptMethod VersionTree Generalize {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    return $this.Root.Generalize().Item1
}

AddScriptMethod VersionTree ToString {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion] $Version
    )

    return $this.Root.ToString()
}

#endregion

function GeneralizeVersions {
    [CmdletBinding()]
    [OutputType([String[]])]
    param(
        [Parameter(Mandatory)]
        [SemanticVersion[]] $AllVersions,
        [Parameter(Mandatory)]
        [SemanticVersion[]] $VersionSubset
    )

    [PSCustomObject] $tree = NewVersionTree
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
