param(
    [switch]$NoDeploy
)

chcp 65001

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$info = Get-Content -Path "info.json" -Raw | ConvertFrom-Json
$stageName = "$($info.name)_$($info.version)"
$stage = Join-Path $root $stageName
$zipPath = Join-Path $root "$stageName.zip"

$ignores = @('.git', '.gitignore', '.vscode', 'crowdin.yml', '*.zip', '*.psd')
$ignores += $info.package.ignore

function Test-Ignored {
    param([string]$Name, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        if ($p.EndsWith('/**')) {
            if ($Name -eq $p.Substring(0, $p.Length - 3)) { return $true }
        } elseif (-not $p.Contains('/')) {
            if ($Name -like $p) { return $true }
        }
    }
    return $false
}

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

foreach ($item in (Get-ChildItem -Path $root -Force)) {
    if ($item.FullName -eq $stage) { continue }
    if (Test-Ignored -Name $item.Name -Patterns $ignores) {
        Write-Output "skip: $($item.Name)"
        continue
    }
    Copy-Item -LiteralPath $item.FullName -Destination $stage -Recurse
}

tar -a -c -f $zipPath $stageName
if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
Remove-Item -LiteralPath $stage -Recurse -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName })
    $topLevel = @($entries | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique)
    if ($topLevel.Count -ne 1 -or $topLevel[0] -ne $stageName) {
        throw "Bad zip layout. Top-level: $($topLevel -join ', ')"
    }
    if ($entries -notcontains "$stageName/info.json") {
        throw "$stageName/info.json not found in zip"
    }
} finally {
    $zip.Dispose()
}

$size = (Get-Item -LiteralPath $zipPath).Length
Write-Output "packed: $stageName.zip ($size bytes, $($entries.Count) entries, layout OK)"

if (-not $NoDeploy) {
    $dest = Join-Path (Join-Path $env:APPDATA 'Factorio\mods') "$stageName.zip"
    Copy-Item -LiteralPath $zipPath -Destination $dest -Force
    Write-Output "deployed: $dest"
}
