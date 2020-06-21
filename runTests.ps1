Push-Location $PSScriptRoot
try {
    Import-Module pester -Force
    [PesterConfiguration] $config = [PesterConfiguration]::Default

    # Exit with non-zero exit code when the test run fails.
    $config.Run.Exit = $true

    Invoke-Pester -Configuration $config
} finally {
    Pop-Location
}
