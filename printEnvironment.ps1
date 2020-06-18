Set-PSDebug -Trace 1

[Environment]::GetEnvironmentVariables()
[Environment]::Version
[Environment]::CommandLine

$Host
$Host.UI
$Host.RawUI
$Host.PrivateData
$Host.Runspace
$Host.Runspace.InitialSessionState
$Host.Runspace.SessionStateProxy

$PSVersionTable

Get-Variable | Format-Table

Get-Item "$PSHOME\*.json" | ForEach-Object { $_.Name; Get-Content $_ }

Set-PSDebug -Off
