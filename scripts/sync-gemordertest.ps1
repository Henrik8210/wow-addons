# Sync GemOrderTest from GemOrder (same version, test-specific names/prefix).
# Run from repo root: .\scripts\sync-gemordertest.ps1 [-Version 0.7.80]

param(
    [string]$Version = $(if (Test-Path "GemOrder\GemOrder.toc") {
        (Select-String -Path "GemOrder\GemOrder.toc" -Pattern "## Version: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    } else { "?" })
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src = Join-Path $root "GemOrder"
$dst = Join-Path $root "GemOrderTest"

function Convert-GemOrderToTest([string]$text) {
    $text = $text -replace 'GemOrderDB', 'GemOrderTestDB'
    $text = $text -replace 'GemOrder_', 'GemOrderTest_'
    $text = $text -replace 'GemOrder\.', 'GemOrderTest.'
    $text = $text -replace 'GemOrder =', 'GemOrderTest ='
    $text = $text -replace '"GemOrder', '"GemOrderTest'
    $text = $text -replace '\^GemOrder', '^GemOrderTest'
    $text = $text -replace 'GEMORDER_', 'GEMORDERTEST_'
    $text = $text -replace '\|cff00ccffGemOrder\|r', '|cff00ccffGemOrderTest|r'
    $text = $text -replace '\|cffff0000GemOrder', '|cffff0000GemOrderTest'
    $text = $text -replace 'local PREFIX = "GemOrderTest"', 'local PREFIX = "GemOrdT"'
    return $text
}

$luaFiles = @(
    "Core.lua", "Gems.lua", "Gear.lua", "Rooms.lua", "Stock.lua",
    "Recipes.lua", "Tooltips.lua", "Sync.lua", "UI.lua", "Minimap.lua"
)

foreach ($file in $luaFiles) {
    $sourcePath = Join-Path $src $file
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "Missing $file - skipped"
        continue
    }
    $content = Get-Content -Path $sourcePath -Raw -Encoding UTF8
    $content = Convert-GemOrderToTest $content
    Set-Content -Path (Join-Path $dst $file) -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Synced $file"
}

# Commands: transform then apply test slash aliases
$commandsSrc = Get-Content -Path (Join-Path $src "Commands.lua") -Raw -Encoding UTF8
$commands = Convert-GemOrderToTest $commandsSrc
$commandLines = $commands -split "`r?`n"
$filtered = @()
foreach ($line in $commandLines) {
    if ($line -match '^SLASH_GEMORDERTEST') { continue }
    if ($line -match '^SLASH_GEMORDER') { continue }
    if ($line -match 'SlashCmdList\[') {
        $line = 'SlashCmdList["GEMORDERTEST"] = function(msg)'
        $filtered += $line
        continue
    }
    $filtered += $line
}
$commandsBody = ($filtered -join "`r`n").TrimStart()
$commands = "SLASH_GEMORDERTEST1 = `"/gotest`"`r`nSLASH_GEMORDERTEST2 = `"/got`"`r`nSLASH_GEMORDERTEST3 = `"/gott`"`r`n`r`n" + $commandsBody
Set-Content -Path (Join-Path $dst "Commands.lua") -Value $commands -Encoding UTF8 -NoNewline
Write-Host "Synced Commands.lua"

# Update .toc
$toc = @"
## Interface: 20505, 20506
## Title: GemOrderTest
## Notes: Bisect/debug mirror of GemOrder v$Version. Separate saved vars and sync prefix (GemOrdT). Disable main GemOrder when testing logout.
## Author: Henrik8210
## Version: $Version
## SavedVariables: GemOrderTestDB

Core.lua
Gems.lua
Gear.lua
Rooms.lua
Stock.lua
Recipes.lua
Tooltips.lua
Sync.lua
UI.lua
Minimap.lua
Commands.lua
"@
Set-Content -Path (Join-Path $dst "GemOrderTest.toc") -Value $toc.TrimEnd() -Encoding UTF8
Write-Host "Updated GemOrderTest.toc to v$Version"

Write-Host "Done. GemOrderTest synced to v$Version"
