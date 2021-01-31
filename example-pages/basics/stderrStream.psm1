function GetTitle {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    return 'The stderr stream'
}

function RunPage {
    [CmdletBinding()]
    [OutputType([String[]])]
    param()

    OutputSection 'Basic case' {
        OutputText @'
        When `ErrorActionPreference` is `Continue`, stderr in PowerShell
        behaves similarly to stderr in other shells. Most stderr output by
        commands you call will be sent directly to the PowerShell process's own
        stderr. It is interesting to note, however, that assigning the stderr
        command to a variable, casting it to `Void`, or piping it to `Out-Null`
        produces different results.

        Here is the output from writing directly to stderr. All versions print
        both lines to stderr.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Continue'

            cmd /c 'echo printing to stderr 1 >&2'
            cmd /c 'echo printing to stderr 2 >&2'
        }

        OutputText @'
        Here we are redirecting to stdout, `$null`, and a file. Nothing prints
        the `$null` line. Versions 2 and 5 write the stdout line to stderr,
        while PowerShell Core writes it to stdout. All versions correctly write
        to the file, with versions 2 and 5 including stack traces.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Continue'

            cmd /c 'echo redirecting stderr to stdout >&2' 2>&1
            cmd /c 'echo redirecting stderr to $null >&2' 2> $null
            cmd /c 'echo redirecting stderr to a file >&2' 2> error.txt
            Write-Output "error.txt: $((Get-Content error.txt) -join `"`n`")"
        }

        OutputText @'
        And finally here we redirect to a variable, cast to `Void`, and
        redirect to `Out-Null`. All PowerShell versions behave the same for
        these examples.

        All versions assign stderr to the variable if it's redirected and
        otherwise print to stderr and leave the variable blank. The
        non-redirected `Void` and `Out-Null` cases print to stderr, and the
        redirected cases print nothing.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Continue'

            $v = cmd /c 'echo assigning command result to a variable >&2'
            Write-Output "`$v: $v"
            $v = cmd /c 'echo assigning redirected command result to a variable >&2' 2>&1
            Write-Output "`$v: $v"
            [Void] (cmd /c 'echo casting stderr command to Void >&2')
            [Void] (cmd /c 'echo casting redirected stderr command to Void >&2' 2>&1)
            cmd /c 'echo piping stderr command to Out-Null >&2' | Out-Null
            cmd /c 'echo piping redirected stderr command to Out-Null >&2' 2>&1 | Out-Null
        }

        OutputText @'
        If you redirect stderr while `ErrorActionPreference` is `Stop`, an
        exception is generated. Here we have the same groupings, first writing
        directly to stderr. Since we aren't redirecting stderr, no exceptions
        are thrown.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Stop'

            try {
                cmd /c 'echo printing to stderr 1 >&2'
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                cmd /c 'echo printing to stderr 2 >&2'
            } catch {
                Write-Output "Caught: $_"
            }
        }

        OutputText @'
        Then redirecting to stdout, `$null`, or a file all cause exceptions.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Stop'

            try {
                cmd /c 'echo redirecting stderr to stdout >&2' 2>&1
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                cmd /c 'echo redirecting stderr to $null >&2' 2> $null
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                cmd /c 'echo redirecting stderr to a file >&2' 2> error.txt
            } catch {
                Write-Output "Caught: $_"
            }

            Write-Output "error.txt: $((Get-Content error.txt) -join `"`n`")"
        }

        OutputText @'
        And finally assigning to a variable, casting to `Void`, or redirecting
        to `Out-Null` throw exceptions for all cases where stderr is redirected
        to stdout (which makes sense, since redirecting to stdout by itself
        throws).

        Assigning to a variable without redirection leaves the variable empty
        and prints to stderr. Casting stderr to `Void` and piping to `Out-Null`
        both print to stderr as well.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Stop'

            try {
                $v = cmd /c 'echo assigning command result to a variable >&2'
                Write-Output "`$v: $v"
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                $v = cmd /c 'echo assigning redirected command result to a variable >&2' 2>&1
                Write-Output "`$v: $v"
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                [Void] (cmd /c 'echo casting stderr command to Void >&2')
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                [Void] (cmd /c 'echo casting redirected stderr command to Void >&2' 2>&1)
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                cmd /c 'echo piping stderr command to Out-Null >&2' | Out-Null
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                cmd /c 'echo piping redirected stderr command to Out-Null >&2' 2>&1 | Out-Null
            } catch {
                Write-Output "Caught: $_"
            }
        }
    }

    OutputSection 'Class methods' {
        OutputText @'
        This behavior has interesting consequences for class methods (See
        [[Method stdio#Stderr]]). Since non-void methods automatically suppress
        stdio, it's as if they were redirecting stderr to `$null`, so printing
        to stderr within a non-void method will produce an exception when
        `ErrorActionPreference` is `Stop`.

        `Void` methods don't suppress stderr, even though they suppress stdout.
        So, calling `VoidFunc` will print to stderr.
'@

        OutputCode -MinVersion 5 {
            $local:ErrorActionPreference = 'Stop'

            class C {
                [String] StringFunc() {
                    cmd /c 'echo StringFunc: printing to stderr 1 >&2'
                    cmd /c 'echo StringFunc: printing to stderr 2 >&2'
                    return 'some string'
                }

                [Void] VoidFunc() {
                    cmd /c 'echo VoidFunc: printing to stderr 1 >&2'
                    cmd /c 'echo VoidFunc: printing to stderr 2 >&2'
                }
            }

            $c = [C]::new()

            try {
                $c.StringFunc()
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                $c.VoidFunc()
            } catch {
                Write-Output "Caught: $_"
            }
        }

        OutputText @'
        When `ErrorActionPreference` is `Continue`, `StringFunc`'s return value
        gets printed to stdout (which makes sense, since it's returned), and it
        prints its other lines to stderr. `VoidFunc` prints both its lines to
        stderr.

        What's interesting is that in GitHub Actions runners (where this site
        was generated), everything in `StringFunc` is printed to stderr without
        a newline after it. This results in the first line from `VoidFunc`
        being on the same line as all `StringFunc` output. On my (binyomen's)
        machine, nothing in `StringFunc` is printed at all. Since methods with
        return values should supress stdio, it seems like my machine has the
        "correct" behavior. This is, needless to say, extremely confusing, and
        is tracked by [Issue
        29](https://github.com/binyomen/pwsh-live-doc/issues/29).
'@

        OutputCode -MinVersion 5 {
            $local:ErrorActionPreference = 'Continue'

            class C {
                [String] StringFunc() {
                    cmd /c 'echo Note: These lines only seem to print on GitHub Actions >&2'
                    cmd /c 'echo StringFunc: printing to stderr 1 >&2'
                    cmd /c 'echo StringFunc: printing to stderr 2 >&2'
                    return 'some string'
                }

                [Void] VoidFunc() {
                    cmd /c 'echo VoidFunc: printing to stderr 1 >&2'
                    cmd /c 'echo VoidFunc: printing to stderr 2 >&2'
                }
            }

            $c = [C]::new()

            try {
                $c.StringFunc()
            } catch {
                Write-Output "Caught: $_"
            }

            try {
                $c.VoidFunc()
            } catch {
                Write-Output "Caught: $_"
            }
        }
    }

    OutputSection 'See also' {
        OutputText @'
        [This PowerShellTraps
        page](https://github.com/nightroman/PowerShellTraps/tree/master/Basic/App-with-error-output)
        is also an incredible source for information about stderr.
'@
    }
}
