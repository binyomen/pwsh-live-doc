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
filter is running on. Releases are instances of `PSCustomObject` as specified
by [the GitHub releases
API](https://developer.github.com/v3/repos/releases/#list-releases-for-a-repository).
If the script block returns true, the release will be included in the
downloads.

The script block will have access to all functions in
`downloadPwshPackages.ps1`. You don't want to call most of them, but
`GetVersionFromRelease` is provided so that you can get the version of a given
release.

For example, if you only wanted to download version 7.0.0, you could do:

```powershell
.\downloadPwshPackages.ps1 -ReleaseFilter {
    param($AllReleases, $ReleaseToCheck)
    $v = GetVersionFromRelease($ReleaseToCheck)
    return $v -eq [System.Management.Automation.SemanticVersion]::new(7, 0, 0)
}
```

### Run buildSite.ps1

This will generate the files for the site, using all the PowerShell versions in
`pwsh-packages`. This script outputs the site to the `webroot` directory.

### View the site locally

If you ran `buildSite.ps1`, the `webroot` directory will now contain the root
of the site. Point a static file server like
[http-server](https://www.npmjs.com/package/http-server) to `webroot` and view
the site from `localhost` in your browser.

## Development

### Adding example topics

Each group of examples is stored in a script in the `example-scripts`
directory. Each script should contain examples for a specific topic. If you
want to add a new topic, you should create a new file.

### Example script helper functions

Helper functions for the example scripts can be imported with `Import-Module
-Force $PSScriptRoot\..\docgen` at the top of the script.

#### OutputTitle

This function is called to generate an HTML `h2` element for your particular
example topic. You should always put this at the top of your script after
importing docgen.

#### OutputText

This function takes a string of markdown code. This markdown is translated into
HTML on the page.

#### OutputCode

This function takes a script block. The script block should not depend on any
state outside of it. It will be converted into a string and then run in
separate PowerShell processes with `<exename> -c $scriptBlockString`.

The functions from the util module (e.g. `NewErrorRecord`) will be available
within your script block.

After running the script block against multiple versions of PowerShell,
`OutputCode` generates HTML to display the code block as well as a table of
outputs from the PowerShell processes, grouped by PowerShell version.

### HTML generation

The entry point for generating the site is the `buildSite.ps1` script. This
script runs all scripts in `example-scripts` and uses the output to build the
site.

The bulk of site logic generation is in the docgen module.

### Downloading PowerShell packages

All the code for the package downloader can be found in
`downloadPwshPackages.ps1`.

### Continuous Integration

All continuous integration is performed by GitHub Actions. The configuration
files are in `.github\workflows\`. The workflows test the code, generate the
site, and deploy it to GitHub Pages.
