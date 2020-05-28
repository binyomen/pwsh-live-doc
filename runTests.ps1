Push-Location $PSScriptRoot
try {
    # Invoke-Pester needs to run in its own powershell session because
    # otherwise classes in modules like docgen get cached and can't be changed
    # during development. Import-Module -Force doesn't work with classes :(
    pwsh -c {
        Import-Module pester -Force
        $config = [PesterConfiguration]::Default

        # Exit with non-zero exit code when the test run fails.
        $config.Run.Exit = $true

        Invoke-Pester -Configuration $config
    }
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $exitCode
