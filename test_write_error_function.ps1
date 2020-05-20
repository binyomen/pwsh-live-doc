Import-Module -Force $PSScriptRoot\testmodule.psm1
try {
    TestWriteErrorFunction
} catch {
    Write-Host "caught outside the cmdlet: $_"
}
