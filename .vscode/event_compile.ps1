chcp 65001

$Original = Get-Content -Path readme.md -Raw -Encoding UTF8
$Result = 'return [==[' + $Original + ']==]'

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines("src/wiki/readme.src.lua", $Result, $Utf8NoBomEncoding)
