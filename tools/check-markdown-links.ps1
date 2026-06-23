#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Slug {
    param([string]$Text)

    $slug = $Text.Trim().ToLowerInvariant()
    $slug = $slug -replace '`', ''
    $slug = $slug -replace '<[^>]+>', ''
    $slug = $slug -replace '[^a-z0-9 _-]', ''
    $slug = $slug -replace '\s+', '-'
    $slug = $slug -replace '-+', '-'
    return $slug.Trim('-')
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$markdownFiles = Get-ChildItem -Path $repoRoot -Recurse -File -Filter "*.md"
$errors = [System.Collections.Generic.List[string]]::new()
$slugMap = @{}

foreach ($file in $markdownFiles) {
    $slugs = @{}
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        if ($line -match '^(#{1,6})\s+(.+)$') {
            $base = Get-Slug $Matches[2]
            if (-not $base) { continue }

            if ($slugs.ContainsKey($base)) {
                $slugs[$base] += 1
                $slug = "$base-$($slugs[$base])"
            } else {
                $slugs[$base] = 0
                $slug = $base
            }
            $slugs[$slug] = 0
        }
    }
    $slugMap[$file.FullName] = $slugs.Keys
}

foreach ($file in $markdownFiles) {
    $raw = Get-Content -LiteralPath $file.FullName -Raw
    $dir = $file.DirectoryName
    $matches = [regex]::Matches($raw, '\[[^\]]+\]\(([^)]+)\)')

    foreach ($match in $matches) {
        $link = $match.Groups[1].Value
        if ($link -match '^(https?:|mailto:)') { continue }

        $targetPart = ($link -split '#', 2)[0]
        $anchor = if ($link.Contains('#')) { ($link -split '#', 2)[1] } else { "" }

        if ([string]::IsNullOrWhiteSpace($targetPart)) {
            $target = $file.FullName
        } else {
            if ($targetPart -notmatch '\.md$' -and $targetPart -notmatch '/$') { continue }
            $target = Join-Path $dir $targetPart
        }

        if (-not (Test-Path -LiteralPath $target)) {
            $errors.Add("$($file.FullName) -> $link")
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($anchor)) {
            $resolved = (Resolve-Path -LiteralPath $target).Path
            $slug = Get-Slug $anchor
            if ($slug -and $slugMap.ContainsKey($resolved) -and -not ($slugMap[$resolved] -contains $slug)) {
                $errors.Add("$($file.FullName) -> $link (missing #$slug)")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | Sort-Object | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Markdown links and anchors OK"
