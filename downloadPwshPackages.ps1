using namespace System.Management.Automation

[CmdletBinding()]
[OutputType([Void])]
param(
    [ScriptBlock] $ReleaseFilter = {
        param($AllReleases, $ReleaseToCheck)

        [SemanticVersion] $version = GetVersionFromRelease($ReleaseToCheck)
        return (-not $ReleaseToCheck.prerelease) -and
            ($version.PreReleaseLabel -eq $null) -and
            ($version.BuildLabel -eq $null)
    }
)

Set-StrictMode -Version Latest
$script:ErrorActionPreference = "Stop"

# This function is in scope here, and so it can be used in any script blocks
# passed to $ReleaseFilter.
function GetVersionFromRelease {
    [CmdletBinding()]
    [OutputType([SemanticVersion])]
    param(
        [PSCustomObject] $Release
    )

    [String] $tagName = $Release.tag_name
    [String] $versionString = $tagName[1..($tagName.Length - 1)] -join ""
    return [SemanticVersion]::new($versionString)
}

function GetNextUrl {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $Link
    )

    [String[]] $items = $Link -split ","
    foreach ($item in $items) {
        if ($item -match "<(.+)>\s*;\s*rel=`"next`"") {
            return $matches[1]
        }
    }

    return ""
}

function WriteRateLimit {
    [CmdletBinding()]
    [OutputType([Void])]
    param()

    [PSCustomObject] $rates = (Invoke-RestMethod "https://api.github.com/rate_limit")
    [UInt32] $limit = $rates.resources.core.limit
    [UInt32] $remaining = $rates.resources.core.remaining
    [UInt64] $reset = $rates.resources.core.reset

    [TimeSpan] $timeUntilReset = (Get-Date 01.01.1970) +`
        [TimeSpan]::FromSeconds($reset) -`
        (Get-Date).ToUniversalTime()
    [String] $resetString = "$($timeUntilReset.Hours)h$($timeUntilReset.Minutes)m$($timeUntilReset.Seconds)s from now"

    Write-Host "Rate limit:"
    Write-Host "Limit: $limit, Remaining: $remaining, Reset: $resetString"
}

function GetAllReleaseUrls {
    [CmdletBinding()]
    [OutputType([Tuple`3[[String], [String], [Int64]][]])]
    param()

    [String] $url = "https://api.github.com/repos/PowerShell/PowerShell/releases"
    [PSCustomObject[]] $releases = @()
    do {
        $releases += (Invoke-RestMethod $url -ResponseHeadersVariable headers)
        WriteRateLimit

        $url = GetNextUrl $headers["Link"][0] # there should only be one
    } while ($url -ne "")

    [PSCustomObject[]] $filteredReleases = $releases |`
        # We never want to consider releases with versions less than 6, since
        # they don't define the assets we're looking for.
        Where-Object { [SemanticVersion] $v = GetVersionFromRelease $_; $v -ge [SemanticVersion]::new(6) } |`
        Where-Object { Invoke-Command $ReleaseFilter -Args $releases, $_ }

    [Tuple`3[[String], [String], [Int64]][]] $assetUrls = $filteredReleases | ForEach-Object {
        [PSCustomObject] $release = $_
        [PSCustomObject] $asset = ($release.assets | Where-Object { $_.name -match "-win-x64.zip`$" })[0] # there should only be one
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

    [String] $packageDir = "$PSScriptRoot\pwsh-packages"
    if (-not (Test-Path $packageDir)) {
        mkdir $packageDir > $null
    }

    foreach ($pair in $UrlPairs) {
        [String] $name = $pair.Item1
        [String] $url = $pair.Item2
        [Int64] $size = $pair.Item3

        [String] $extractPath = "$packageDir\$name"
        [String] $zipPath = "$extractPath.zip"
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

[Tuple`3[[String], [String], [Int64]][]] $urls = GetAllReleaseUrls
DownloadUrls $urls
