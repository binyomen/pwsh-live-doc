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
        When `ErrorActionPreference` is `Continue`, stderr in PowerShell behaves
        similarly to stderr in other shells. Any stderr output by commands you call
        will be sent directly to the PowerShell process's own stderr.
'@

        OutputCode {
            $local:ErrorActionPreference = 'Continue'

            cmd /c 'echo printing to stderr 1 >&2'
            cmd /c 'echo printing to stderr 2 >&2'
            cmd /c 'echo redirecting stderr to stdout >&2' 2>&1
            cmd /c 'echo redirecting stderr to $null >&2' 2> $null
            cmd /c 'echo redirecting stderr to a file >&2' 2> error.txt
            [Void] (cmd /c 'echo casting stderr command to Void >&2')
            [Void] (cmd /c 'echo casting redirected stderr command to Void >&2' 2>&1)
            cmd /c 'echo piping stderr command to Out-Null >&2' | Out-Null
            cmd /c 'echo piping redirected stderr command to Out-Null >&2' 2>&1 | Out-Null

            Write-Output "error.txt: $((Get-Content error.txt) -join `"`n`")"
        }

        OutputText @'
        Even when `ErrorActionPreference` is `Stop`, the behavior is partially the
        same.
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
                [Void] (cmd /c 'echo casting stderr command to Void >&2')
            } catch {
                Write-Output "Caught: $_"
            }
            try {
                cmd /c 'echo piping stderr command to Out-Null >&2' | Out-Null
            } catch {
                Write-Output "Caught: $_"
            }
        }

        OutputText @'
        However, when you redirect stderr while `ErrorActionPreference` is `Stop`,
        an exception will be generated.
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
            try {
                [Void] (cmd /c 'echo casting redirected stderr command to Void >&2' 2>&1)
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
        [[methodOutput.psm1]]). Since non-void methods automatically suppress
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
        When `ErrorActionPreference` is `Continue`, it seems to mostly behave like
        you'd expect. Non-void methods suppress stderr, and void methods don't. On
        GitHub Actions runners, though (where this site was generated), stderr
        seems to be emitted as a single line. This isn't the case on my
        (benweedon's) machine. [Issue
        29](https://github.com/benweedon/pwsh-live-doc/issues/29) tracks this.
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
