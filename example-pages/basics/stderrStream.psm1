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
'@

    OutputSection 'Basic case' {
        OutputText @'
        When `ErrorActionPreference` is `Continue`, stderr in PowerShell Core
        behaves similarly to stderr in other shells. Any stderr output by
        commands you call will be sent directly to the PowerShell process's own
        stderr. It is interesting to note, however, that assigning the stderr
        command a variable, casting it to `Void`, or piping it to `Out-Null`
        results in the stderr stream being received by stdout.

        In PowerShell 2 and 5, the result is much different. Not only
        are stack traces printed out to stderr (except for the first print),
        nothing is printed to stdout. Everything is printed to stderr except
        redirecting to `$null` or a file and the redirect version of the
        variable, `Void`, and `Out-Null` cases.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Continue'

            cmd /c 'echo printing to stderr 1 >&2'
            cmd /c 'echo printing to stderr 2 >&2'
            cmd /c 'echo redirecting stderr to stdout >&2' 2>&1
            cmd /c 'echo redirecting stderr to $null >&2' 2> $null
            cmd /c 'echo redirecting stderr to a file >&2' 2> error.txt
            $v = cmd /c 'echo assigning command result to a variable >&2'
            Write-Output "`$v: $v"
            $v = cmd /c 'echo assigning redirected command result to a variable >&2' 2>&1
            Write-Output "`$v: $v"
            [Void] (cmd /c 'echo casting stderr command to Void >&2')
            [Void] (cmd /c 'echo casting redirected stderr command to Void >&2' 2>&1)
            cmd /c 'echo piping stderr command to Out-Null >&2' | Out-Null
            cmd /c 'echo piping redirected stderr command to Out-Null >&2' 2>&1 | Out-Null

            Write-Output "error.txt: $((Get-Content error.txt) -join `"`n`")"
        }

        OutputText @'
        If you redirect stderr while `ErrorActionPreference` is `Stop`, an
        exception is generated.
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

            Write-Output "error.txt: $((Get-Content error.txt) -join `"`n`")"
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
