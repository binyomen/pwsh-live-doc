using namespace System.Collections.Generic
using namespace System.Management.Automation

[CmdletBinding()]
[OutputType([Void])]
param(
    [ScriptBlock] $ReleaseFilter = {
        param($AllReleases, $ReleaseToCheck)

        $version = GetVersionFromRelease($ReleaseToCheck)
        return (-not $ReleaseToCheck.prerelease) -and
            ($version.PreReleaseLabel -eq $null) -and
            ($version.BuildLabel -eq $null) -and
            ($version -ge [SemanticVersion]::new("6"))
    }
)

$local:ErrorActionPreference = "Stop"

# This function is in scope here, and so it can be used in any script blocks
# passed to $ReleaseFilter.
function GetVersionFromRelease {
    [CmdletBinding()]
    [OutputType([SemanticVersion])]
    param(
        [PSCustomObject] $Release
    )

    $tagName = $Release.tag_name
    $versionString = $tagName[1..$tagName.length] -join ""
    return [SemanticVersion]::new($versionString)
}

function GetNextUrl {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $Link
    )

    $items = $Link -split ","
    foreach ($item in $items) {
        if ($item -match "<(.+)>\s*;\s*rel=`"next`"") {
            return $matches[1]
        }
    }

    return $null
}

function WriteRateLimit {
    [CmdletBinding()]
    [OutputType([Void])]
    param()

    $rates = (Invoke-RestMethod "https://api.github.com/rate_limit")
    $limit = $rates.resources.core.limit
    $remaining = $rates.resources.core.remaining
    $reset = $rates.resources.core.reset

    $timeUntilReset = (Get-Date 01.01.1970) +`
        [TimeSpan]::FromSeconds($reset) -`
        (Get-Date).ToUniversalTime()
    $resetString = "$($timeUntilReset.Hours)h$($timeUntilReset.Minutes)m$($timeUntilReset.Seconds)s from now"

    Write-Host "Rate limit:"
    Write-Host "Limit: $limit, Remaining: $remaining, Reset: $resetString"
}

function GetAllReleaseUrls {
    [CmdletBinding()]
    [OutputType([Tuple`3[[String], [String], [Int64]][]])]
    param()

    $url = "https://api.github.com/repos/PowerShell/PowerShell/releases"
    $releases = @()
    do {
        $releases += (Invoke-RestMethod $url -ResponseHeadersVariable headers)
        WriteRateLimit

        $url = GetNextUrl $headers["Link"][0] # there should only be one
    } while ($url -ne $null)

    $filteredReleases = $releases | Where-Object { Invoke-Command $ReleaseFilter -Args $releases,$_ }
    $assetUrls = $filteredReleases | ForEach-Object {
        $release = $_
        $asset = ($release.assets | Where-Object { $_.name -match "-win-x64.zip`$" })[0] # there should only be one
        return [Tuple]::Create($release.tag_name, $asset.url, $asset.size)
    }

    return $assetUrls
}

function ExtractPackage {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [String] $ZipPath,
        [String] $ExtractPath
    )

    try {
        Expand-Archive $ZipPath $ExtractPath
        Remove-Item -Force $ZipPath
    } catch {
        Remove-Item $ExtractPath -Recurse -Force -ErrorAction "Continue"
    }
}

function DownloadUrls {
    [CmdletBinding()]
    [OutputType([Void])]
    param(
        [Tuple`3[[String], [String], [Int64]][]] $UrlPairs
    )

    $packageDir = "$PSScriptRoot\pwsh-packages"
    if (-not (Test-Path $packageDir)) {
        mkdir $packageDir > $null
    }

    foreach ($pair in $UrlPairs) {
        $name = $pair.Item1
        $url = $pair.Item2
        $size = $pair.Item3

        $extractPath = "$packageDir\$name"
        $zipPath = "$extractPath.zip"
        if (-not (Test-Path $extractPath)) {
            Write-Host

            if (-not (Test-Path $zipPath)) {
                Write-Host "Downloading $url to $zipPath..."
                Write-Host "Size: $([Math]::Round($size / 1mb, 1))MB ($size bytes)"
                Invoke-RestMethod $url -Headers @{Accept="application/octet-stream"} -OutFile $zipPath
                WriteRateLimit
            }

            Write-Host "Extracting $zipPath to $extractPath..."
            ExtractPackage $zipPath $extractPath
        }
    }
}

$urls = GetAllReleaseUrls
DownloadUrls $urls
