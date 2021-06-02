function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'PSCustomObject'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputSection 'Count property' {
        OutputText @'
        When not running in strict mode, most objects in PowerShell have a
        `Count` property:
'@

        OutputCode {
            $array = @(1, 2, 3)
            Write-Output "Array count: $($array.Count)"

            $dictionary = @{A=1; B=2; C=3; D=4}
            Write-Output "Dictionary count: $($dictionary.Count)"

            $number = 5
            Write-Output "Number count: $($number.Count)"

            $string = 'hello there'
            Write-Output "String count: $($string.Count)"

            $process = (Get-Process)[0]
            Write-Output "Process object count: $($process.Count)"
        }

        OutputText @'
        Notice that all these objects have a `Count` (except for
        non-collections in version 2). However, `PSCustomObject` doesn't have
        an accurate `Count` of 1 until version 6.1. In version 2, it has the
        same count as the dictionary it was created out of.
'@

        OutputCode {
            $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
            Write-Output "PSCustomObject count: $($object.Count)"
        }

        OutputText @'
        If we enable strict mode, we get some more differing behavior between
        versions.

        In version 2, we fail to get the count on the number, string, and
        process objects. Everything else is the same. In versions 5 and 6.0, we
        throw getting the count on everything but the actual collections.
        Versions 6.1 and up interestingly have the same behavior as versions 5
        and 6.0, except they actually succeed in getting the `PSCustomObject`
        count.
'@

        OutputCode {
            Set-StrictMode -Version Latest

            try {
                $array = @(1, 2, 3)
                Write-Output "Array count: $($array.Count)"
            } catch {
                Write-Output "Array count threw: $_"
            }

            try {
                $dictionary = @{A=1; B=2; C=3; D=4}
                Write-Output "Dictionary count: $($dictionary.Count)"
            } catch {
                Write-Output "Dictionary count threw: $_"
            }

            try {
                $number = 5
                Write-Output "Number count: $($number.Count)"
            } catch {
                Write-Output "Number count threw: $_"
            }

            try {
                $string = 'hello there'
                Write-Output "String count: $($string.Count)"
            } catch {
                Write-Output "String count threw: $_"
            }

            try {
                $process = (Get-Process)[0]
                Write-Output "Process object count: $($process.Count)"
            } catch {
                Write-Output "Process object count threw: $_"
            }

            try {
                $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                Write-Output "PSCustomObject count: $($object.Count)"
            } catch {
                Write-Output "PSCustomObject count threw: $_"
            }
        }
    }
}
