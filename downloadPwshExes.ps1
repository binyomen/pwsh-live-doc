using namespace System.Management.Automation

function GetNextUrl {
    [CmdletBinding()]
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

function GetAllReleaseUrls {
    [CmdletBinding()]
    param()

    $url = "https://api.github.com/repos/PowerShell/PowerShell/releases"
    $releases = @()
    do {
        $releases += (Invoke-RestMethod $url -ResponseHeadersVariable headers)

        Write-Host "Rate limit:"
        Write-Host "Limit: $($headers['X-Ratelimit-Limit']), Remaining: $($headers['X-Ratelimit-Remaining']), Reset: $($headers['X-Ratelimit-Reset'])"
        Write-Host

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

(GetAllReleaseUrls) -join "`n"
