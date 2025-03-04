Clear-Host
Write-Host "`n" -NoNewline
Write-Host " ============================================" -ForegroundColor Green
Write-Host "   Lua Obfuscation Tool v1.0" -ForegroundColor Green
Write-Host " ============================================" -ForegroundColor Green
Write-Host "`n" -NoNewline

# Check if script.txt exists, create if it doesn't
$inputFile = "script.txt"
$outputFile = "output.txt"

if (-not (Test-Path $inputFile)) {
    Write-Host "[*] No script.txt found! Creating template..." -ForegroundColor Yellow
    Set-Content -Path $inputFile -Value "local function printMessage()`n    print(`"Hello, World!`")`nend`n`nprintMessage()"
    Write-Host "[+] Template script.txt created" -ForegroundColor Green
}

Write-Host "[*] Loading script.txt..." -ForegroundColor Cyan
$luaCode = Get-Content -Path $inputFile -Raw -Encoding UTF8

# Function to generate random names
function Get-RandomName {
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $length = Get-Random -Minimum 5 -Maximum 15
    return "_" + (-join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() }))
}

# String encryption - Skip single characters
function Encrypt-String($str) {
    if ($str.Length -le 1) { # Skip single-character strings (operators)
        Write-Host "[DEBUG] Skipping encryption for single char '$str'" -ForegroundColor Magenta
        return "`"$str`""
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $byteString = ($bytes | ForEach-Object { $_ }) -join ", "
    $encrypted = "string.char($byteString)"
    Write-Host "[DEBUG] Encrypting '$str' to: $encrypted" -ForegroundColor Magenta
    return $encrypted
}

# Number obfuscation
function Obfuscate-Number($num) {
    $ops = @(
        { "$num + " + (Get-Random -Minimum 1 -Maximum 10) + " - " + (Get-Random -Minimum 1 -Maximum 10) },
        { "$num * 2 / 2" },
        { "$num - " + (Get-Random -Minimum 1 -Maximum 5) + " + " + (Get-Random -Minimum 1 -Maximum 5) }
    )
    return & (Get-Random -InputObject $ops)
}

# List of Lua built-in functions to exclude from renaming
$luaBuiltins = @("print", "assert", "error", "ipairs", "pairs", "next", "select", "tonumber", "tostring", "type", "unpack", "pcall", "xpcall", "rawget", "rawset", "rawequal", "setmetatable", "getmetatable", "math", "string", "table", "io")

# Obfuscation process
$varMap = @{}
$funcMap = @{}
$obfuscatedCode = $luaCode

# 1. Function renaming (exclude built-ins)
$funcPattern = "function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("
$funcMatches = [regex]::Matches($luaCode, $funcPattern)
foreach ($match in $funcMatches) {
    $funcName = $match.Groups[1].Value
    if (-not $luaBuiltins.Contains($funcName) -and -not $funcMap.ContainsKey($funcName)) {
        $funcMap[$funcName] = Get-RandomName
        $obfuscatedCode = $obfuscatedCode -replace "\b$funcName\b(?=\s*\()", $funcMap[$funcName]
    }
}

# 2. Variable renaming
$localVarPattern = "local\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:=|$)"
$varMatches = [regex]::Matches($obfuscatedCode, $localVarPattern)
foreach ($match in $varMatches) {
    $varName = $match.Groups[1].Value
    if (-not $varMap.ContainsKey($varName)) {
        $varMap[$varName] = Get-RandomName
    }
    $obfuscatedCode = $obfuscatedCode -replace "\b$varName\b", $varMap[$varName]
}

# 3. Number obfuscation (before strings)
$numberPattern = '\b(\d+)\b'
$numberMatches = [regex]::Matches($obfuscatedCode, $numberPattern)
foreach ($match in $numberMatches) {
    $number = $match.Groups[1].Value
    $obfuscatedNum = Obfuscate-Number $number
    $obfuscatedCode = $obfuscatedCode -replace "\b$number\b", $obfuscatedNum
}

# 4. String encryption (after numbers, skip operators)
$stringPattern = '"([^"]*)"'
$stringsProcessed = @{}
$obfuscatedCode = [regex]::Replace($obfuscatedCode, $stringPattern, {
    param($match)
    $originalString = $match.Groups[1].Value
    if (-not $stringsProcessed.ContainsKey($originalString)) {
        $stringsProcessed[$originalString] = Encrypt-String $originalString
    }
    return $stringsProcessed[$originalString]
})

# 5. Add junk code
$junkCode = @"
do
    local {0} = math.random(1 + 5 - 5, 100 * 2 / 2)
    if {0} > 0 then
        {0} = {0} - {0}
    end
end
"@ -f (Get-RandomName)
$obfuscatedCode = $junkCode + "`n" + $obfuscatedCode

# Write to output file with explicit UTF-8 encoding
Write-Host "[*] Writing obfuscated code to output.txt..." -ForegroundColor Cyan
Set-Content -Path $outputFile -Value $obfuscatedCode -Encoding UTF8
Write-Host "[+] Obfuscation complete!" -ForegroundColor Green
Write-Host "`n[*] Final output preview:" -ForegroundColor Cyan
Write-Host $obfuscatedCode -ForegroundColor Cyan
Write-Host "`n[*] Mappings:" -ForegroundColor Cyan
Write-Host "Variables:" -ForegroundColor Cyan
$varMap.GetEnumerator() | Sort-Object Name | Format-Table -Property Name,Value -AutoSize | Out-String | Write-Host -ForegroundColor Cyan
Write-Host "Functions:" -ForegroundColor Cyan
$funcMap.GetEnumerator() | Sort-Object Name | Format-Table -Property Name,Value -AutoSize | Out-String | Write-Host -ForegroundColor Cyan

# Wait for user input before closing
Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
Read-Host