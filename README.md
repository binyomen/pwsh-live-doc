# PowerShell Live Docs

Run real code examples to generate empirical documentation of the complex
nonsense that is PowerShell semantics. Deploy the documentation to a static web
site.

See <https://benweedon.github.io/pwsh-live-doc/> for the current live site.

## Building locally

### Use Windows

This code only works on Windows at the moment. We might eventually extend it to
Linux and macOS as well.

### Install at least PowerShell 7

The build code itself is designed for the newest version of PowerShell. At the
moment, that's 7. Some of it may work on older versions, but that hasn't been
tested. If there's demand for it to work on older versions, we can look into
supporting that :)

You can install the latest version of PowerShell from
<https://github.com/PowerShell/PowerShell/releases>.

### Clone this repository

You can clone it with `git clone
https://github.com/benweedon/pwsh-live-doc.git` or `git clone
git@github.com:benweedon/pwsh-live-doc.git`.

### Run downloadPwshPackages.ps1

This will download all release versions of PowerShell that haven't already been
downloaded into `<clonepath>\pwsh-packages\`. Each subdirectory of
`pwsh-packages` will be a self-contained, portable deployment of a specific
version of PowerShell.

If you don't want to download all the packages (eating up your time and
bandwidth, and rate-limiting you for the GitHub API), you can specify a script
block to the `downloadPwshPackages.ps1` -ReleaseFilter parameter. The script
block will be passed two arguments: a list of all releases available on the
repository greater than version 6 (because versions lower than 6 are the 0.x
versions which don't have the assets we want) and the current release the
filter is running on. If the script block returns true, the release will be
included in the downloads.

The script block will have access to all functions in
`downloadPwshPackages.ps1`. You don't want to call most of them, but
`GetVersionFromRelease` is provided so that you can get the version of a given
release.

For example, if you only wanted to download version 7.0.0, you could do:

```powershell
.\downloadPwshPackages.ps1 -ReleaseFilter {
    param($AllReleases, $ReleaseToCheck)
    $v = GetVersionFromRelease($AllReleases)
    return $v -eq [System.Management.Automation.SemanticVersion]::new(7, 0, 0)
}
```

### Run generateHtml.ps1

This will generate the HTML for the site, using all the PowerShell versions in
`pwsh-packages`. This script outputs the HTML to stdout, so if you want it say
in index.html you can run `.\generateHtml.ps1 > index.html`.

### View the site locally

If you generated index.html in the previous step, the root of the repository
can now be the webroot of the site. Run a static file server like
[http-server](https://www.npmjs.com/package/http-server) in the repository's
root and point your browser to wherever it says to.
