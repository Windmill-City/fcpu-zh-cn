param(
    [string]$ModsDir = ''
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Test-Path -LiteralPath (Join-Path $root 'info.json'))) {
    throw "info.json not found in $root"
}

$info = Get-Content -LiteralPath (Join-Path $root 'info.json') -Raw | ConvertFrom-Json
$name = $info.name
$version = $info.version
$folderName = "$name`_$version"
$zipName = "$folderName.zip"

$distDir = Join-Path $root 'dist'
$zipPath = Join-Path $distDir $zipName
$stageDir = Join-Path $env:TEMP $folderName

if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDir | Out-Null

robocopy $root $stageDir /E /XD .git dist /XF build.ps1 /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}
$LASTEXITCODE = 0

if (-not (Test-Path -LiteralPath $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}
Compress-Archive -Path $stageDir -DestinationPath $zipPath -Force
Remove-Item -LiteralPath $stageDir -Recurse -Force

Write-Host "Built $zipPath"

$candidates = @(
    (Join-Path $env:APPDATA 'Factorio\mods'),
    (Join-Path $env:USERPROFILE 'AppData\Roaming\Factorio\mods'),
    (Join-Path $env:USERPROFILE 'Documents\Factorio\mods')
)

if ($ModsDir -ne '') {
    $candidates = @($ModsDir)
}

$modsDir = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
        $modsDir = $c
        break
    }
}

if ($modsDir) {
    Copy-Item -LiteralPath $zipPath -Destination (Join-Path $modsDir $zipName) -Force
    Write-Host "Copied $zipName to $modsDir"
} else {
    Write-Host "Factorio mods directory not found. Zip kept at $zipPath"
}
