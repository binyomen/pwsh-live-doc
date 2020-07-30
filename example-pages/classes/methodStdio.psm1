function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'Method stdio'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputText @'
    Class methods in PowerShell are different from functions created with the
    `function` keyword. They behave more like functions in languages like C#,
    requiring a single return value and checking its type.

    This means they don't subscribe to the pattern of normal PowerShell
    functions that stdout is the return value and stderr is the error details.
    Instead, `return` is required to return a value and errors are handled with
    exceptions.
'@

    OutputSection 'Stdout' {
        OutputText @'
        Stdout is never output to the console, no matter the return type of the
        method.
'@

        OutputCode -MinVersion 5 {
            class C {
                [String] Func1() {
                    Write-Output 'Func1: writing string to stdout'
                    return 'Func1: returning a string'
                }

                [String] Func2() {
                    cmd /c 'echo Func2: writing string to stdout'
                    return 'Func2: returning a string'
                }

                [UInt32] Func3() {
                    Write-Output 'Func3: writing string to stdout'
                    return 3
                }

                [UInt32] Func4() {
                    cmd /c 'echo Func4: writing string to stdout'
                    return 4
                }

                [Void] Func5() {
                    Write-Output 'Func5: writing string to stdout'
                }

                [Void] Func6() {
                    cmd /c 'echo Func6: writing string to stdout'
                }
            }

            $c = [C]::new()
            $c.Func1()
            $c.Func2()
            $c.Func3()
            $c.Func4()
            $c.Func5()
            $c.Func6()
        }
    }

    OutputSection 'Stderr' {
        OutputText @'
        See [[The stderr stream#Class methods|the stderr stream page]].
'@
    }

    OutputSection 'Stdin' {
        OutputText 'TODO'
    }
}
