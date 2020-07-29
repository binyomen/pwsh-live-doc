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

        OutputText @'
        Note: On GitHub Actions runners (where this site was generated), the
        output is different than on my (benweedon's) machine. [Issue
        29](https://github.com/benweedon/pwsh-live-doc/issues/29) tracks this.
        Best not to trust anything on this page until we have this figured out.
'@

    OutputSection 'Basic case' {
        OutputText @'
        When `ErrorActionPreference` is `Continue`, stderr in PowerShell Core
        behaves similarly to stderr in other shells. Most stderr output by
        commands you call will be sent directly to the PowerShell process's own
        stderr. It is interesting to note, however, that assigning the stderr
        command to a variable, casting it to `Void`, or piping it to `Out-Null`
        results in the stderr stream being received by stdout.

        In PowerShell 2 and 5, the result is much different. Not only are stack
        traces printed out to stderr (except for the first print for some
        reason), nothing is printed to stdout. Everything is printed to stderr
        except redirecting to `$null` or a file and the redirect version of the
        variable, `Void`, and `Out-Null` cases.

        Here is the output from writing directly to stderr. All versions print
        the same things, except that versions 2 and 5 have stack traces:
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
        to the file, with versions 2 and 5 including stack traces:
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
        redirect to `Out-Null`. This test has huge variations between versions.
        All versions handle variables the same, assigning stderr to the
        variable if it's redirected and otherwise printing to stderr and
        leaving the variable blank???????????????:
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
        are thrown except in versions 2 and 5, which seem to like throwing the
        second time you write to stderr for some reason:
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
        Then redirecting to stdout, `$null`, or a file all cause exceptions:
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
        And finally redirecting to a variable, casting to `Void`, or
        redirecting to `Out-Null` ??????:
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
        stdio, it's as if they were redirecting stderr to $null, so printing to
        stderr within a non-void method will produce an exception when
        `ErrorActionPreference` is `Stop`.

        Void methods don't suppress stderr, though, even though they suppress
        stdout.
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
        When `ErrorActionPreference` is `Continue`, it seems to mostly behave
        like you'd expect. Non-void methods suppress stderr, and void methods
        don't.
'@

        OutputCode -MinVersion 5 {
            $local:ErrorActionPreference = 'Continue'

            class C {
                [String] StringFunc() {
                    cmd /c 'echo Note: This line only seems to print on GitHub Actions >&2'
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
