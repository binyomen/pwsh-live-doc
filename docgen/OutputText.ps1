function NewInternalLink {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [String] $LinkSyntax
    )

    [String] $linkElementPattern = '[^\[\]#|]+'
    [String] $innerLinkPattern = "^($linkElementPattern)(#$linkElementPattern)?(\|$linkElementPattern)?`$"

    if (-not ($LinkSyntax -cmatch $innerLinkPattern)) {
        throw "Invalid link format: [[$LinkSyntax]]"
    }

    [String[]] $matchList = @()
    foreach ($i in 1..3) {
        if ($matches.ContainsKey($i)) {
            $matchList += $matches[$i]
        } else {
            break
        }
    }

    [String] $pageTitle = $matchList[0]
    $matchList = GetRest $matchList

    [String] $pageSection = ''
    [String] $linkText = ''
    while ($matchList.Count -gt 0) {
        [String] $firstMatch = $matchList[0]

        if ($firstMatch.StartsWith('#')) {
            $pageSection = $firstMatch.Substring(1)
        } elseif ($firstMatch.StartsWith('|')) {
            $linkText = $firstMatch.Substring(1)
        } else {
            throw 'Incorrectly parsed syntax'
        }

        $matchList = GetRest $matchList
    }

    return [PSCustomObject]@{
        PSTypeName = 'InternalLink'
        Syntax = $LinkSyntax
        Title = $pageTitle
        Section = $pageSection
        Text = $linkText
    }
}

AddScriptMethod InternalLink AsMarkdown {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    if (-not $script:outline.ContainsKey($this.Title)) {
        throw "Page does not exist: '$($this.Title)'"
    }
    [String] $pageLink = $script:outline[$this.Title].Item1
    [Dictionary[String, String]] $pageOutline = $script:outline[$this.Title].Item2

    if ($this.Section.Length -gt 0) {
        if (-not $pageOutline.ContainsKey($this.Section)) {
            throw "Section does not exist: '$($this.Title)#$($this.Section)'"
        }

        $pageLink += '#' + $pageOutline[$this.Section]
    }

    if ($this.Text.Length -gt 0) {
        [String] $linkText = $this.Text
    } else {
        [String] $linkText = $this.Title
    }

    return "[$linkText]($pageLink)"
}

AddScriptMethod InternalLink ToString {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [String] $s = $this.Title

    if ($this.Section.Length -gt 0) {
        $s += '#' + $this.Section
    }

    if ($this.Text.Length -gt 0) {
        $s += ' (' + $this.Text + ')'
    }

    return $s
}

function ParseInternalLinks {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    [String] $linkPattern = '\[\[(.+)\]\]'
    if (-not ($Text -cmatch $linkPattern)) {
        return $Text
    }

    [String[]] $linkSyntaxes = @()
    [Int32] $i = 1
    while ($true) {
        if ($matches.ContainsKey($i)) {
            $linkSyntaxes += $matches[$i]
        } else {
            break
        }

        ++$i
    }

    [PSCustomObject[]] $links = $linkSyntaxes | ForEach-Object { NewInternalLink $_ }

    [String] $newText = $Text
    $links | ForEach-Object {
        [PSCustomObject] $link = $_
        Write-Host "Generating link for page '$($link.ToString())'"

        [String] $markdownLink = $link.AsMarkdown()
        # The Replace method doesn't use regex.
        $newText = $newText.Replace("[[$($link.Syntax)]]", $markdownLink)
    }

    return $newText
}

function OutputText {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $Text
    )

    if ($script:buildingOutline) {
        return
    }

    [String] $formattedText = FormatPageText $Text
    [String] $linkedText = ParseInternalLinks $formattedText
    [String] $rawHtml = (ConvertFrom-Markdown -InputObject $linkedText).Html
    return $rawHtml -replace "<p>", "<p class=`"content-text`">"
}
