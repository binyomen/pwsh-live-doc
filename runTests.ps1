Push-Location $PSScriptRoot
try {
    # Invoke-Pester needs to run in its own powershell session because
    # otherwise classes in modules like docgen get cached and can't be changed
    # during development. Import-Module -Force doesn't work with classes :(
    pwsh -c Invoke-Pester -EnableExit
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $exitCode
