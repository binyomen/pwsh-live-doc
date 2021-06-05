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

    OutputSection 'Collection-like behavior' {
        OutputSection 'Permissive mode' {
            OutputText @'
            When not running in strict mode, most objects in PowerShell have a
            `Count` property:
'@

            OutputCode {
                $array = @(1, 2, 3)
                Write-Output "Array Count: $($array.Count)"

                $dictionary = @{A=1; B=2; C=3; D=4}
                Write-Output "Dictionary Count: $($dictionary.Count)"

                $number = 5
                Write-Output "Number Count: $($number.Count)"

                $string = 'hello there'
                Write-Output "String Count: $($string.Count)"

                $process = (Get-Process)[0]
                Write-Output "Process object Count: $($process.Count)"
            }

            OutputText @'
            Notice that all these objects have a `Count` (except for
            non-collections in version 2). However, `PSCustomObject` doesn't
            have an accurate `Count` of 1 until version 6.1. In version 2, it
            has the same count as the dictionary it was created out of.
'@

            OutputCode {
                $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                Write-Output "PSCustomObject Count: $($object.Count)"
            }

            OutputText @'
            Basically, `PSCustomObject` sometimes doesn't act like a collection
            when other single types do until version 6.1.

            We can also look at other collection invocations. The `Length`
            property behaves the same as `Count` in that most objects act like
            collections, but `PSCustomObject` doesn't start acting like a
            collection until version 6.1. There's just the one difference that
            in version 2, `Length` on `PSCustomObject` doesn't return the
            number of properties in the object like with `Count`.

            Naturally, other types like strings also behave differently with
            `Length`, but we're just interested in `PSCustomObject` here.
'@

            OutputCode {
                $array = @(1, 2, 3)
                Write-Output "Array Length: $($array.Length)"

                $dictionary = @{A=1; B=2; C=3; D=4}
                Write-Output "Dictionary Length: $($dictionary.Length)"

                $number = 5
                Write-Output "Number Length: $($number.Length)"

                $string = 'hello there'
                Write-Output "String Length: $($string.Length)"

                $process = (Get-Process)[0]
                Write-Output "Process object Length: $($process.Length)"

                $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                Write-Output "PSCustomObject Length: $($object.Length)"
            }

            OutputText @'
            The `ForEach` method behaves similarly to `Count` and `Length`
            except it throws rather than returning null. Also note that
            dictionaries behave like singular objects with `ForEach`.
'@

            OutputCode {
                try {
                    $array = @(1, 2, 3)
                    $i = -1
                    Write-Output "Array ForEach: $($array.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Array ForEach threw: $_"
                }

                try {
                    $dictionary = @{A=1; B=2; C=3; D=4}
                    $i = -1
                    Write-Output "Dictionary ForEach: $($dictionary.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Dictionary ForEach threw: $_"
                }

                try {
                    $number = 5
                    $i = -1
                    Write-Output "Number ForEach: $($number.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Number ForEach threw: $_"
                }

                try {
                    $string = 'hello there'
                    $i = -1
                    Write-Output "String ForEach: $($string.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "String ForEach threw: $_"
                }

                try {
                    $process = (Get-Process)[0]
                    $i = -1
                    Write-Output "Process object ForEach: $($process.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Process object ForEach threw: $_"
                }

                try {
                    $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                    $i = -1
                    Write-Output "PSCustomObject ForEach: $($object.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "PSCustomObject object ForEach threw: $_"
                }
            }

            OutputText @'
            Zero indexing, interestingly, works in all versions 5 through 7,
            whether number, process object, or `PSCustomObject`. In version 2,
            it returns null on `PSCustomObject` rather than throwing like with
            numbers and process objects. This matches the behavior that the
            `PSCustomObject` cast in version 2 really just produces a
            dictionary.
'@

            OutputCode {
                try {
                    $array = @(1, 2, 3)
                    Write-Output "Array [0]: $($array[0])"
                } catch {
                    Write-Output "Array [0] threw: $_"
                }

                try {
                    $dictionary = @{A=1; B=2; C=3; D=4}
                    Write-Output "Dictionary [0]: $($dictionary[0])"
                } catch {
                    Write-Output "Dictionary [0] threw: $_"
                }

                try {
                    $number = 5
                    Write-Output "Number [0]: $($number[0])"
                } catch {
                    Write-Output "Number [0] threw: $_"
                }

                try {
                    $string = 'hello there'
                    Write-Output "String [0]: $($string[0])"
                } catch {
                    Write-Output "String [0] threw: $_"
                }

                try {
                    $process = (Get-Process)[0]
                    Write-Output "Process object [0]: $($process[0])"
                } catch {
                    Write-Output "Process object [0] threw: $_"
                }

                try {
                    $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                    Write-Output "PSCustomObject [0]: $($object[0])"
                } catch {
                    Write-Output "PSCustomObject [0] threw: $_"
                }
            }
        }

        OutputSection 'Strict mode' {
            OutputText @'
            If we enable strict mode, we get some more differing behavior
            between versions.

            In version 2, we fail to get the count on the number, string, and
            process objects. Everything else is the same. In versions 5 and
            6.0, we throw getting the count on everything but the actual
            collections. Like when not in strict mode, we only start getting
            `Count` on `PSCustomObject` starting in version 6.1. This is
            interesting, however, because `PSCustomObject` is now the only
            non-collection type which doesn't throw in strict mode.
'@

            OutputCode {
                Set-StrictMode -Version Latest

                try {
                    $array = @(1, 2, 3)
                    Write-Output "Array Count: $($array.Count)"
                } catch {
                    Write-Output "Array Count threw: $_"
                }

                try {
                    $dictionary = @{A=1; B=2; C=3; D=4}
                    Write-Output "Dictionary Count: $($dictionary.Count)"
                } catch {
                    Write-Output "Dictionary Count threw: $_"
                }

                try {
                    $number = 5
                    Write-Output "Number Count: $($number.Count)"
                } catch {
                    Write-Output "Number Count threw: $_"
                }

                try {
                    $string = 'hello there'
                    Write-Output "String Count: $($string.Count)"
                } catch {
                    Write-Output "String Count threw: $_"
                }

                try {
                    $process = (Get-Process)[0]
                    Write-Output "Process object Count: $($process.Count)"
                } catch {
                    Write-Output "Process object Count threw: $_"
                }

                try {
                    $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                    Write-Output "PSCustomObject Count: $($object.Count)"
                } catch {
                    Write-Output "PSCustomObject Count threw: $_"
                }
            }

            OutputText @'
            We see something similar with the `Length` property. Up until
            version 6.1, all types but arrays and strings throw. However, once
            we reach 6.1, `PSCustomObject` now has a `Length` property, even in
            strict mode.
'@

            OutputCode {
                Set-StrictMode -Version Latest

                try {
                    $array = @(1, 2, 3)
                    Write-Output "Array Length: $($array.Length)"
                } catch {
                    Write-Output "Array Length threw: $_"
                }

                try {
                    $dictionary = @{A=1; B=2; C=3; D=4}
                    Write-Output "Dictionary Length: $($dictionary.Length)"
                } catch {
                    Write-Output "Dictionary Length threw: $_"
                }

                try {
                    $number = 5
                    Write-Output "Number Length: $($number.Length)"
                } catch {
                    Write-Output "Number Length threw: $_"
                }

                try {
                    $string = 'hello there'
                    Write-Output "String Length: $($string.Length)"
                } catch {
                    Write-Output "String Length threw: $_"
                }

                try {
                    $process = (Get-Process)[0]
                    Write-Output "Process object Length: $($process.Length)"
                } catch {
                    Write-Output "Process object Length threw: $_"
                }

                try {
                    $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                    Write-Output "PSCustomObject Length: $($object.Length)"
                } catch {
                    Write-Output "PSCustomObject Length threw: $_"
                }
            }

            OutputText @'
            `ForEach` works on all types in versions 5 and 6.0 in strict mode,
            except for `PSCustomObject`. In version 6.1 it works for
            `PSCustomObject` as well. This differs from `Count` and `Length`,
            in that supporting `ForEach` on `PSCustomObject` in strict mode
            actually produces consistency with other types.
'@

            OutputCode {
                Set-StrictMode -Version Latest

                try {
                    $array = @(1, 2, 3)
                    $i = -1
                    Write-Output "Array ForEach: $($array.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Array ForEach threw: $_"
                }

                try {
                    $dictionary = @{A=1; B=2; C=3; D=4}
                    $i = -1
                    Write-Output "Dictionary ForEach: $($dictionary.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Dictionary ForEach threw: $_"
                }

                try {
                    $number = 5
                    $i = -1
                    Write-Output "Number ForEach: $($number.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Number ForEach threw: $_"
                }

                try {
                    $string = 'hello there'
                    $i = -1
                    Write-Output "String ForEach: $($string.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "String ForEach threw: $_"
                }

                try {
                    $process = (Get-Process)[0]
                    $i = -1
                    Write-Output "Process object ForEach: $($process.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "Process object ForEach threw: $_"
                }

                try {
                    $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                    $i = -1
                    Write-Output "PSCustomObject ForEach: $($object.ForEach({$i += 1; $i}))"
                } catch {
                    Write-Output "PSCustomObject ForEach threw: $_"
                }
            }

            OutputText @'
            Finally, zero indexing works on all types in versions 5 through 7,
            even in strict mode.
'@

            OutputCode {
                Set-StrictMode -Version Latest

                try {
                    $array = @(1, 2, 3)
                    Write-Output "Array [0]: $($array[0])"
                } catch {
                    Write-Output "Array [0] threw: $_"
                }

                try {
                    $dictionary = @{A=1; B=2; C=3; D=4}
                    Write-Output "Dictionary [0]: $($dictionary[0])"
                } catch {
                    Write-Output "Dictionary [0] threw: $_"
                }

                try {
                    $number = 5
                    Write-Output "Number [0]: $($number[0])"
                } catch {
                    Write-Output "Number [0] threw: $_"
                }

                try {
                    $string = 'hello there'
                    Write-Output "String [0]: $($string[0])"
                } catch {
                    Write-Output "String [0] threw: $_"
                }

                try {
                    $process = (Get-Process)[0]
                    Write-Output "Process object [0]: $($process[0])"
                } catch {
                    Write-Output "Process object [0] threw: $_"
                }

                try {
                    $object = [PSCustomObject]@{A=1; B=2; C=3; D=4; E=5}
                    Write-Output "PSCustomObject [0]: $($object[0])"
                } catch {
                    Write-Output "PSCustomObject [0] threw: $_"
                }
            }
        }

        OutputSection 'See also' {
            OutputText @'
            - [PSCustomObject does not have surrogate Count and
              Length | PowerShellTraps](https://github.com/nightroman/PowerShellTraps/tree/master/Basic/Count-and-Length/PSCustomObject)
            - [Treating scalars implicitly as collections doesn't fully work
              with custom objects ([pscustomobject]) - lacks a .Count
              property | GitHub Issue](https://github.com/PowerShell/PowerShell/issues/3671)
            - [Treating scalars implicitly as collections doesn't work with all
              objects - some lack a .Count property, as do some objects that
              are implicitly treated as
              collections | GitHub Issue](https://github.com/PowerShell/PowerShell/issues/6456)
            - [Set-Strictmode should not complain about COUNT & LENGTH
              properties on
              elements | GitHub Issue](https://github.com/PowerShell/PowerShell/issues/2798)
'@
        }
    }
}
