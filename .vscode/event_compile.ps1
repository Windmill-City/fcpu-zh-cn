chcp 65001

function Convert-ToLuaReturn {
    param(
        [string]$InputPath,
        [string]$OutputPath
    )

    $Original = Get-Content -Path $InputPath -Raw -Encoding UTF8
    $Result = 'return [==[' + $Original + ']==]'

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($OutputPath, $Result, $Utf8NoBomEncoding)
}

Convert-ToLuaReturn "readme.md" "src/wiki/readme.en.src.lua"
Convert-ToLuaReturn "readme.ru.md" "src/wiki/readme.ru.src.lua"