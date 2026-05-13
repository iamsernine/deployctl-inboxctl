# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
# One-off / maintenance script: embed standardized OSS metadata (run from repo root if needed).
# Not required for CI.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "README.md"))) {
    $root = "c:\Users\sernine\Desktop\SE\deployInboxExample\deployctl-inboxctl"
}

$mdPrefix = @"
<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->

"@

$shInsert = @"
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
"@

function Normalize-Lf([string]$s) {
    return $s -replace "`r`n", "`n"
}

Get-ChildItem -Path $root -Recurse -Filter *.md -File | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    if ($c -notmatch "Project: deployctl-inboxctl") {
        [System.IO.File]::WriteAllText($_.FullName, (Normalize-Lf ($mdPrefix + $c)))
    }
}

Get-ChildItem -Path $root -Recurse -Filter *.sh -File | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    if ($c -match "Project: deployctl-inboxctl") { return }
    if ($c -notmatch "^#!") { return }
    $lineEnd = if ($c -match "`r`n") { "`r`n" } else { "`n" }
    if ($c -match "^(#[^\r\n]+)(\r?\n)") {
        $c2 = $Matches[0] + $shInsert + $lineEnd + $c.Substring($Matches[0].Length)
        [System.IO.File]::WriteAllText($_.FullName, (Normalize-Lf $c2))
    }
}

$lic = Join-Path $root "LICENSE"
if (Test-Path $lic) {
    $lc = [System.IO.File]::ReadAllText($lic)
    if ($lc -notmatch "Project: deployctl-inboxctl") {
        $pre = @"
<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Copyright: replace YOUR_NAME_OR_ORG in the line below
-->

"@
        [System.IO.File]::WriteAllText($lic, (Normalize-Lf ($pre + $lc)))
    }
}

Write-Output "embed-project-headers: done (root=$root)"
