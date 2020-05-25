using namespace System.Collections.Generic
using namespace System.Management.Automation

$local:ErrorActionPreference = "Stop"

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
    [OutputType([Tuple`2[[String], [String]][]])]
    param()

    $url = "https://api.github.com/repos/PowerShell/PowerShell/releases"
    $releases = @()
    do {
        $releases += (Invoke-RestMethod $url -ResponseHeadersVariable headers)
        WriteRateLimit

        $url = GetNextUrl $headers["Link"][0] # there should only be one
    } while ($url -ne $null)

    function GetVersionFromRelease($Release) {
        $tagName = $Release.tag_name
        $versionString = $tagName[1..$tagName.length] -join ""
        return [SemanticVersion]::new($versionString)
    }

    $filteredReleases = $releases |`
        Where-Object { -not $_.prerelease } |`
        Where-Object { $v = GetVersionFromRelease($_); $v.PreReleaseLabel -eq $null } |`
        Where-Object { $v = GetVersionFromRelease($_); $v.BuildLabel -eq $null } |`
        Where-Object { $v = GetVersionFromRelease($_); $v -ge [SemanticVersion]::new("6") }

    $assetUrls = $filteredReleases | ForEach-Object {
        $release = $_
        $asset = ($release.assets | Where-Object { $_.name -match "-win-x64.zip`$" })[0] # there should only be one
        return [Tuple]::Create($release.tag_name, $asset.url)
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
        [Tuple`2[[String], [String]][]] $UrlPairs
    )

    $packageDir = "$PSScriptRoot\pwsh-packages"
    if (-not (Test-Path $packageDir)) {
        mkdir $packageDir > $null
    }

    foreach ($pair in $UrlPairs) {
        $name = $pair.Item1
        $url = $pair.Item2

        $extractPath = "$packageDir\$name"
        $zipPath = "$extractPath.zip"
        if (-not (Test-Path $extractPath)) {
            Write-Host

            if (-not (Test-Path $zipPath)) {
                Write-Host "Downloading $url to $zipPath..."
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
