Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

$mod_vs = Get-ChildItem "${env:APPDATA}\Factorio\mods\${env:FACTORIO_MODNAME}_*.*.*"

if($mod_vs.Count -eq 1) {
    Rename-Item -Path $mod_vs -NewName "${env:FACTORIO_MODNAME}_${env:FACTORIO_MODVERSION}"
} else {
    Write-Output "Error renaming mod in Factorio folder. Found multiple versions:" ($mod_vs | ForEach-Object {"-- " + $_.Name})
}
