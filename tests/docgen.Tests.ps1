using namespace System.Management.Automation

Import-Module -Force $PSScriptRoot\..\docgen

function global:V {
    [CmdletBinding()]
    [OutputType([SemanticVersion[]])]
    param(
        [String[]] $VersionStrings
    )

    $VersionStrings | ForEach-Object { [SemanticVersion]::new($_) }
}

[SemanticVersion[]] $global:allVersions = (V `
    0.1.0,`
    0.2.0,`
    0.3.0,`
    0.4.0,`
    0.5.0,`
    0.6.0,`
    6.0.0,`
    6.0.1,`
    6.0.2,`
    6.0.3,`
    6.0.4,`
    6.0.5,`
    6.1.0,`
    6.1.1,`
    6.1.2,`
    6.1.3,`
    6.1.4,`
    6.1.5,`
    6.1.6,`
    6.2.0,`
    6.2.1,`
    6.2.2,`
    6.2.3,`
    6.2.4,`
    6.2.5,`
    7.0.0,`
    7.0.1)

Describe "VersionTree" {
    InModuleScope docgen {
        It "starts out as empty" {
            [VersionTree]::new().ToString() | Should -Be "root"
        }

        It "can add a single version" {
            [VersionTree] $tree = [VersionTree]::new()
            $tree.Add((V 1.2.3))
            $tree.ToString() | Should -Be "(root (1 (2 3)))"
        }

        It "can add multiple versions" {
            [VersionTree] $tree = [VersionTree]::new()
            foreach ($version in $allVersions) {
                $tree.Add($version)
            }

            $tree.ToString() | Should -Be "(root (0 (1 0) (2 0) (3 0) (4 0) (5 0) (6 0)) (6 (0 0 1 2 3 4 5) (1 0 1 2 3 4 5 6) (2 0 1 2 3 4 5)) (7 (0 0 1)))"
        }

        It "can mark a single version" {
            [VersionTree] $tree = [VersionTree]::new()
            foreach ($version in $allVersions) {
                $tree.Add($version)
            }

            $tree.MarkVersion((V 6.0.1))

            $tree.ToString() | Should -Be "(root (0 (1 0) (2 0) (3 0) (4 0) (5 0) (6 0)) (6 (0 0 1* 2 3 4 5) (1 0 1 2 3 4 5 6) (2 0 1 2 3 4 5)) (7 (0 0 1)))"
        }

        It "can mark multiple versions" {
            [VersionTree] $tree = [VersionTree]::new()
            foreach ($version in $allVersions) {
                $tree.Add($version)
            }

            $tree.MarkVersion((V 6.0.1))
            $tree.MarkVersion((V 0.1))
            $tree.MarkVersion((V 6.2.4))

            $tree.ToString() | Should -Be "(root (0 (1 0*) (2 0) (3 0) (4 0) (5 0) (6 0)) (6 (0 0 1* 2 3 4 5) (1 0 1 2 3 4 5 6) (2 0 1 2 3 4* 5)) (7 (0 0 1)))"
        }
    }
}

Describe "GeneralizeVersions" {
    InModuleScope docgen {
        It "throws on empty input" {
            { GeneralizeVersions @() @() } | Should -Throw "Cannot bind argument to parameter 'AllVersions' because it is an empty array."
            { GeneralizeVersions (V 0.1.0) @() } | Should -Throw "Cannot bind argument to parameter 'VersionSubset' because it is an empty array."
            { GeneralizeVersions @() (V 6.1.1) } | Should -Throw "Cannot bind argument to parameter 'AllVersions' because it is an empty array."
        }

        It "returns a version on single version input" {
            GeneralizeVersions $allVersions (V 6.0.4) | Should -Be @("6.0.4")
        }

        It "doesn't display patch if patch is zero" {
            GeneralizeVersions $allVersions (V 6.2.0) | Should -Be @("6.2")
        }

        It "generalizes minor versions" {
            GeneralizeVersions $allVersions (V `
                0.1.0,`
                0.2.0,`
                0.3.0,`
                0.4.0,`
                0.5.0,`
                0.6.0,`
                6.0.4,`
                6.1.0,`
                6.2.4,`
                6.2.5,`
                7.0.0,`
                7.0.1) | Should -Be 0.x,6.0.4,6.1,6.2.4,6.2.5,7.x
        }

        It "generalizes patches" {
            GeneralizeVersions $allVersions (V `
                0.1.0,`
                0.2.0,`
                6.0.0,`
                6.0.1,`
                6.0.2,`
                6.0.3,`
                6.0.4,`
                6.0.5,`
                6.2.0,`
                6.2.1,`
                6.2.2,`
                6.2.3,`
                6.2.4,`
                6.2.5,`
                7.0.1) | Should -Be 0.1.y,0.2.y,6.0.y,6.2.y,7.0.1
        }
    }
}
