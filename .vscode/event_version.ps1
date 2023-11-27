chcp 65001

$mod_vs = Get-ChildItem "${env:APPDATA}\Factorio\mods\${env:FACTORIO_MODNAME}_*.*.*"
if($mod_vs.Count -eq 1) {
    Rename-Item -Path $mod_vs -NewName "${env:FACTORIO_MODNAME}_${env:FACTORIO_MODVERSION}"
} elseif($mod_vs.Count -eq 0) {
    Write-Output "No fCPU mod in Factorio folder."
} else {
    Write-Output "Error renaming fCPU mod in Factorio folder. Found multiple versions:" ($mod_vs | ForEach-Object {"-- " + $_.Name})
}

$mod_dir = "W:\Work\KonStg\.factorio_mods"
$mod_vs = Get-ChildItem "$mod_dir\${env:FACTORIO_MODNAME}_*.*.*"
if($mod_vs.Count -eq 1) {
    if($mod_vs -ne "$mod_dir\${env:FACTORIO_MODNAME}_${env:FACTORIO_MODVERSION}") {
        Rename-Item -Path $mod_vs -NewName "${env:FACTORIO_MODNAME}_${env:FACTORIO_MODVERSION}"
    }
} else {
    Write-Output "Error renaming fCPU mod in .factorio_mods folder. Found multiple versions:" ($mod_vs | ForEach-Object {"-- " + $_.Name})
}
