Clear-Host

# --- НАСТРОЙКА КОДИРОВКИ ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# --- ИСПРАВЛЕНИЕ ОШИБКИ ZipArchive ---
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- ПРОВЕРКА ПРАВ АДМИНА ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- БАННЕР ---
$Banner = @"
  ████████╗██╗██████╗ ███████╗     ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗███████╗██████╗ 
  ╚══██╔══╝██║██╔══██╗██╔════╝    ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝██╔════╝██╔══██╗
     ██║   ██║██║  ██║█████╗      ██║     ███████║█████╗  ██║     █████╔╝ █████╗  ██████╔╝
     ██║   ██║██║  ██║██╔══╝      ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██╔══╝  ██╔══██╗
     ██║   ██║██████╔╝███████╗    ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗███████╗██║  ██║
     ╚═╝   ╚═╝╚═════╝ ╚══════╝     ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
"@
Write-Host $Banner -ForegroundColor Cyan
Write-Host "                     ╔═══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "                     ║               [ TIDE CHECKER v1.3 ]                   ║" -ForegroundColor Yellow
Write-Host "                     ║                  By DONGALIN                          ║" -ForegroundColor Yellow
Write-Host "                     ╚═══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""
if (-not $isAdmin) {
    Write-Host "  [!] ВНИМАНИЕ: Скрипт запущен БЕЗ прав администратора." -ForegroundColor Yellow
    Write-Host "      Проверки Prefetch, BAM и Event Logs будут пропущены." -ForegroundColor DarkGray
    Write-Host ""
}

# --- ЗАПРОС ПУТИ ---
Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
Write-Host "  │ [i] Введите путь к папке профиля (mods, logs, config).      │" -ForegroundColor Cyan
Write-Host "  │     Или нажмите Enter для стандартного .minecraft.          │" -ForegroundColor DarkGray
Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
$userInput = Read-Host "  -> Путь"
$userInput = $userInput.Trim('"', "'", ' ')

if (-not $userInput) {
    $basePath = Join-Path $env:APPDATA ".minecraft"
    Write-Host "  [i] Используется стандартный путь: $basePath" -ForegroundColor DarkGray
} else {
    $basePath = $userInput
}

if (-not (Test-Path $basePath)) {
    Write-Host "`n  [!!] ОШИБКА: Папка по пути '$basePath' не существует. Выход." -ForegroundColor Red
    Read-Host; exit
}

$modsPath = Join-Path $basePath "mods"
$logsPath = Join-Path $basePath "logs"
$packsPath = Join-Path $basePath "resourcepacks"
$configPath = Join-Path $basePath "config"
$downloadsPath = Join-Path $env:USERPROFILE "Downloads"

Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
Write-Host "  │  [DIR] Профиль: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$basePath" -NoNewline -ForegroundColor Green; Write-Host " │" -ForegroundColor DarkCyan
Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
Write-Host "`n  [i] Нажмите Enter для начала проверки..." -ForegroundColor DarkGray
Read-Host

$global:totalFound = 0
$global:scanError = $null
$dateThreshold = (Get-Date).AddDays(-14)

# --- СПИСКИ ПАТТЕРНОВ ---
$baseCheatNames = @(
    "wurst", "meteorclient", "liquidbounce", "impact", "bleachhack", "aristois", "sigma", "huzuni", "nodus", "konas", "rusherhack", "doomsday", "wildclient", "liminar", "cheatimeworld", "viabackwards", "viaforge", "viaproxy"
)
$bannedKeywordsFilename = $baseCheatNames + @("killaura", "aimbot", "xray", "wallhack", "freecam", "autoclicker", "triggerbot")

$bannedPatternsLog = @(
    '\bKillAura\b', '\bAimBot\b', '\bAimAssist\b', '\bAutoCrystal\b',
    '\bTriggerBot\b', '\bAutoTotem\b', '\bChestESP\b', '\bStorageESP\b',
    '\bXRay\b', '\bNoFall\b', '\bScaffold\b', '\bSelfDestruct\b',
    '\bPingSpoof\b', '\bVelocity\s*(Hack|Cheat|Module)\b',
    'injected\s+into\s+net\.minecraft',
    'java\.lang\.Runtime.*\.exec',
    'ClassNotFoundException.*(wurst|meteor|liquid)'
)

$cheatStringsMod = @(
    "AimAssist", "AutoAnchor", "AutoCrystal", "AutoTotem", "AutoArmor", 
    "InventoryTotem", "Hitboxes", "JumpReset", "PingSpoof", "SelfDestruct", 
    "ShieldBreaker", "TriggerBot", "Velocity", "AxeSpam", "WebMacro", "FastPlace",
    "KillAura", "AimBot", "XRay", "NoFall", "Scaffold", "DoomsDay", "WildClient", "Liminar"
)

$whitelistMods = @(
    "appleskin", "architectury", "astrix", "asyncparticles", "authme", "axiom", 
    "badoptimizations", "bobby", "capes", "chatools", "cleanf3", "cloth-config", 
    "commandkeys", "debugify", "dynamic-fps", "enhancedblockentities", "entity-view-distance",
    "entityculling", "exordium", "fabric-api", "fabric-language-kotlin", "fast-ip-ping",
    "ferrite-core", "fullbright", "fzzy_config", "gamma-utils", "highlighter", "iceberg",
    "immediatelyfast", "inventoryhud", "itemscroller", "jojomod", "krypton", "lithium",
    "malilib", "midnightlib", "modernfix", "modmenu", "moreculling", "mousetweaks",
    "not-enough-recipe-book", "noxesium", "octolib", "opponentarmorindicator", "particle-core",
    "placeholder-api", "reeses-sodium-options", "removewardeneffect", "scalablelux", "shieldstatus",
    "shulkerboxtooltip", "sodium", "sodium-extra", "ukulib", "voicechat", "walksylib", "wi-zoom",
    "yet-another-config-lib", "zakohealthindicator", "zoomify"
)

# --- ГЛОБАЛЬНЫЕ КЭШИ ---
$global:modrinthHeaders = @{ "User-Agent" = "TideChecker/1.3 (github.com/dongalin)" }
$global:modrinthCache = @{}
$global:jarCache = @{}

# --- ФУНКЦИИ ---
function Get-SHA1 { 
    param ([string]$filePath) 
    try { return (Get-FileHash -Path $filePath -Algorithm SHA1 -ErrorAction Stop).Hash.ToLower() } 
    catch { return $null }
}

function Get-NormalizedSlug {
    param([string]$fileName)
    $n = [System.IO.Path]::GetFileNameWithoutExtension($fileName).ToLower()
    $n = $n -replace '[-_]\d+(\.\d+)*.*$', ''
    return $n
}

function Get-ZoneIdentifier {
    param ([string]$filePath)
    $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
    if ($ads -match "(?m)^HostUrl=(.+)$") {
        $url = $matches[1].Trim()
        if ($url -match "discord|cdn\.discordapp") { return "Discord (Подозрительно)" }
        if ($url -match "mediafire|mega\.nz|drive\.google") { return "Файлообменник ($url)" }
        if ($url -match "github|modrinth|curseforge") { return "Официальный источник" }
        return $url
    }
    return $null
}

function Fetch-Modrinth {
    param ([string]$hash)
    if ($global:modrinthCache.ContainsKey($hash)) { return $global:modrinthCache[$hash] }
    $result = @{ Name = ""; Slug = "" }
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Headers $global:modrinthHeaders -Method Get -UseBasicParsing -ErrorAction Stop
        Start-Sleep -Milliseconds 120
        if ($response.project_id) {
            $projectData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($response.project_id)" -Headers $global:modrinthHeaders -Method Get -UseBasicParsing -ErrorAction Stop
            $result = @{ Name = $projectData.title; Slug = $projectData.slug }
            Start-Sleep -Milliseconds 120
        }
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 429) { Start-Sleep -Seconds 5 }
    }
    $global:modrinthCache[$hash] = $result
    return $result
}

function Check-StringsInJar {
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Path')]
        [string]$jarPath,
        [Parameter(Mandatory=$true, ParameterSetName='Archive')]
        [System.IO.Compression.ZipArchive]$Archive
    )
    $found = [System.Collections.Generic.HashSet[string]]::new()
    $regex = ($cheatStringsMod | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $zip = $null; $dispose = $false
    try {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
            $dispose = $true
        } else {
            $zip = $Archive
        }
        foreach ($entry in $zip.Entries | Where-Object { $_.FullName -match '\.class$' }) {
            $stream = $entry.Open()
            $ms = [System.IO.MemoryStream]::new()
            try {
                $stream.CopyTo($ms)
                $text = [System.Text.Encoding]::GetEncoding(28591).GetString($ms.ToArray())
                foreach ($m in [regex]::Matches($text, $regex, 'IgnoreCase')) {
                    $found.Add($m.Value) | Out-Null
                }
            } finally { $ms.Dispose(); $stream.Close() }
        }
    } catch {} finally { if ($dispose -and $zip) { $zip.Dispose() } }
    return $found
}

function Show-Section {
    param([string]$Number, [string]$Title)
    $line = "  ║ [SCAN] Этап $Number : $Title"
    $padding = 65 - $line.Length
    if ($padding -lt 0) { $padding = 0 }
    Write-Host ""
    Write-Host "  ╔═════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host ("$line" + (" " * $padding) + "║") -ForegroundColor Yellow
    Write-Host "  ╚═════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
}

function Invoke-DeepModScan {
    param([string]$FilePath)
    if ($global:jarCache.ContainsKey($FilePath) -and $global:jarCache[$FilePath].DeepFlags -ne $null) { 
        return $global:jarCache[$FilePath].DeepFlags 
    }
    
    $flags = @()
    $foundStrings = [System.Collections.Generic.HashSet[string]]::new()
    $classCount = 0
    $obfCount = 0
    $hasRuntimeExec = $false
    $hasHttp = $false
    $regex = ($cheatStringsMod | ForEach-Object { [regex]::Escape($_) }) -join '|'
    
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        $nestedJars = $zip.Entries | Where-Object { $_.FullName -match 'META-INF/jars/.*\.jar$' }
        foreach ($nj in $nestedJars) {
            $ms = [System.IO.MemoryStream]::new()
            $nj.Open().CopyTo($ms)
            $ms.Position = 0
            $nestedZip = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Read)
            
            $nestedStrings = Check-StringsInJar -Archive $nestedZip
            if ($nestedStrings.Count -gt 0) { 
                $flags += "Вложенный чит: $($nj.Name) ($($nestedStrings -join ', '))"
                foreach ($ns in $nestedStrings) { $foundStrings.Add($ns) | Out-Null }
            }
            
            $nestedClasses = $nestedZip.Entries | Where-Object { $_.FullName -match '\.class$' }
            $nestedObf = 0
            foreach ($nc in $nestedClasses) {
                $cName = [System.IO.Path]::GetFileNameWithoutExtension(($nc.FullName -split "/")[-1])
                if ($cName -match "^[a-zA-Z0-9]$" -or $cName -match "[\u3040-\u30FF]") { $nestedObf++ }
            }
            if ($nestedClasses.Count -gt 5 -and ($nestedObf / $nestedClasses.Count) -gt 0.2) { $flags += "Вложенный JAR обфусцирован ($($nj.Name))" }
            $nestedZip.Dispose(); $ms.Dispose()
        }

        $classEntries = $zip.Entries | Where-Object { $_.FullName -match '\.class$' -and $_.Name -notmatch '(?i)package-info|module-info' }
        foreach ($entry in $classEntries) {
            $classCount++
            $className = [System.IO.Path]::GetFileNameWithoutExtension(($entry.FullName -split "/")[-1])
            if ($className -match "^[a-zA-Z0-9]$" -or $className -match "[\u3040-\u30FF]" -or $className -match "[\uFF21-\uFF3A\uFF41-\uFF5A]") { $obfCount++ }
            try {
                $st = $entry.Open()
                $ms = New-Object System.IO.MemoryStream
                $st.CopyTo($ms); $st.Close()
                $bytes = $ms.ToArray(); $ms.Dispose()
                $ascii = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
                
                foreach ($m in [regex]::Matches($ascii, $regex, 'IgnoreCase')) {
                    $foundStrings.Add($m.Value) | Out-Null
                }
                
                if ($ascii -match "Runtime" -and $ascii -match "exec") { $hasRuntimeExec = $true }
                if ($ascii -match "HttpURLConnection" -and $ascii -match "openConnection") { $hasHttp = $true }
            } catch {}
        }
        $zip.Dispose()
        
        if ($classCount -gt 20 -and ($obfCount / $classCount) -gt 0.4) { $flags += "Высокая обфускация ($([math]::Round(($obfCount / $classCount) * 100))% классов)" }
        if ($hasRuntimeExec) { $flags += "INFO: Найден Runtime.exec (возможность запуска команд ОС)" }
        if ($hasHttp) { $flags += "INFO: Найден HttpURLConnection (возможность скачивания файлов)" }
    } catch { $flags += "Ошибка анализа JAR: $($_.Exception.Message)" }
    
    $global:jarCache[$FilePath] = @{ DeepFlags = $flags; Strings = $foundStrings }
    return $flags
}

function Get-JarStrings {
    param([string]$FilePath)
    if ($global:jarCache.ContainsKey($FilePath) -and $global:jarCache[$FilePath].Strings -ne $null) { 
        return $global:jarCache[$FilePath].Strings 
    }
    $strings = Check-StringsInJar -jarPath $FilePath
    if ($global:jarCache.ContainsKey($FilePath)) {
        $global:jarCache[$FilePath].Strings = $strings
    } else {
        $global:jarCache[$FilePath] = @{ DeepFlags = @(); Strings = $strings }
    }
    return $strings
}

# --- ОБЕРТКА ДЛЯ try/catch/finally ---
try {
    # --- ЭТАП 1 ---
    Show-Section "1/9" "Глубокий анализ модов (Хеш, Обфускация, Инжекты)"
    if (-not (Test-Path $modsPath)) { 
        Write-Host "  [i] Папка 'mods' не найдена. Пропуск." -ForegroundColor DarkGray 
    } else {
        $files = @(Get-ChildItem -Path $modsPath -Filter *.jar -File -ErrorAction SilentlyContinue)
        $i = 0
        foreach ($file in $files) {
            $i++
            Write-Progress -Activity "Глубокий анализ модов" -Status "Файл $i из $($files.Count): $($file.Name)" -PercentComplete (($i / $files.Count) * 100)
            
            $isSuspicious = $false
            $reasons = @()
            $infoFlags = @()
            $hash = Get-SHA1 $file.FullName
            
            if (-not $hash) {
                $reasons += "Не удалось прочитать файл"
                $isSuspicious = $true
            } else {
                $modData = Fetch-Modrinth -hash $hash
                $isVerified = if ($modData.Slug) { $true } else { $false }
                
                $slug = Get-NormalizedSlug $file.Name
                $isWhitelisted = $false
                foreach ($w in $whitelistMods) { 
                    if ($slug -eq $w -or $slug -match "^$([regex]::Escape($w))[-_](fabric|forge|quilt|neoforge)$") { 
                        $isWhitelisted = $true; break 
                    } 
                }

                if (-not $isVerified) {
                    $deepFlags = Invoke-DeepModScan -FilePath $file.FullName
                    if ($deepFlags.Count -gt 0) { 
                        $criticalFlags = $deepFlags | Where-Object { $_ -notmatch '^INFO:' }
                        $infoFlags = $deepFlags | Where-Object { $_ -match '^INFO:' }
                        if ($criticalFlags.Count -gt 0) { $isSuspicious = $true; $reasons += $criticalFlags }
                    }
                }

                if (-not $isVerified -and -not $isWhitelisted) {
                    $reasons += "Не найден на Modrinth"
                    $isSuspicious = $true
                }

                $zoneId = Get-ZoneIdentifier $file.FullName
                if ($zoneId) {
                    $reasons += "Источник: $zoneId"
                    if ($zoneId -match "Discord|Файлообменник") { $isSuspicious = $true }
                }

                $stringsFound = Get-JarStrings $file.FullName
                if ($stringsFound.Count -gt 0) {
                    $isSuspicious = $true
                    $reasons += "Найдены строки: $($stringsFound -join ', ')"
                }

                $isRecent = $file.LastWriteTime -gt $dateThreshold
                if ($isRecent -and $isSuspicious) { $reasons += "[!] Изменен менее 14 дней назад" }

                if ($isSuspicious) {
                    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor DarkRed
                    Write-Host "  │ [!!] ПОДОЗРИТЕЛЬНЫЙ МОД: $($file.Name)" -ForegroundColor Red
                    Write-Host "  ├─────────────────────────────────────────────────────────┤" -ForegroundColor DarkRed
                    foreach ($r in $reasons) {
                        Write-Host "  │  -> $r" -ForegroundColor DarkRed
                    }
                    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor DarkRed
                    $global:totalFound++
                } else {
                    if ($isVerified) {
                        Write-Host "  [OK] Мод '$($file.Name)' подтвержден на Modrinth ($($modData.Name))" -ForegroundColor Green
                    } else {
                        Write-Host "  [OK] Мод '$($file.Name)' в белом списке" -ForegroundColor Green
                    }
                    if ($infoFlags.Count -gt 0) {
                        foreach ($inf in $infoFlags) {
                            Write-Host "       $inf" -ForegroundColor DarkGray
                        }
                    }
                }
            }
        }
        Write-Progress -Activity "Глубокий анализ модов" -Completed
    }

    # --- ЭТАП 2 ---
    Show-Section "2/9" "Анализ логов"
    $logFiles = @()
    if (-not (Test-Path $logsPath)) { 
        Write-Host "  [i] Папка 'logs' не найдена. Пропуск." -ForegroundColor DarkGray 
    } else {
        $logFiles = @(Get-ChildItem -Path $logsPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.log$|\.txt$|\.log\.gz$' })
        $uniqueIssues = [System.Collections.Generic.List[object]]::new()
        $j = 0

        foreach ($file in $logFiles) {
            $j++
            Write-Progress -Activity "Анализ логов" -Status "Файл $j из $($logFiles.Count)" -PercentComplete (($j / $logFiles.Count) * 100)
            
            $processLine = {
                param($line, $lineNum, $fileName, $list)
                if ($line -match "(?i)GrGrim" -or $line -match "(?i)failed\s+(REACH|ESP)") { return }
                foreach ($pat in $bannedPatternsLog) {
                    if ($line -match $pat) {
                        $list.Add([PSCustomObject]@{File=$fileName;Line=$lineNum;Kw=$pat;Text=$line;Type="C"})
                    }
                }
            }

            if ($file.Name -match '\.gz$') {
                try {
                    $inputStream = [System.IO.File]::OpenRead($file.FullName)
                    $gzipStream = New-Object System.IO.Compression.GzipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
                    $reader = New-Object System.IO.StreamReader($gzipStream)
                    $lineNum = 0
                    while (($line = $reader.ReadLine()) -ne $null) { $lineNum++; & $processLine $line $lineNum $file.Name $uniqueIssues }
                    $reader.Close(); $gzipStream.Close(); $inputStream.Close()
                } catch {}
            } else {
                $lineNum = 0
                Get-Content -Path $file.FullName -ErrorAction SilentlyContinue | ForEach-Object { $lineNum++; & $processLine $_ $lineNum $file.Name $uniqueIssues }
            }
        }
        Write-Progress -Activity "Анализ логов" -Completed

        $uniqueIssues = $uniqueIssues | Sort-Object File, Line, Kw -Unique
        if ($uniqueIssues.Count -eq 0) {
            Write-Host "  [OK] Чисто. В логах нет упоминаний читов." -ForegroundColor Green
        } else {
            foreach ($issue in $uniqueIssues) {
                $global:totalFound++
                Write-Host "  [!!] $($issue.File) (Строка $($issue.Line)): Найдено '$($issue.Kw)'" -ForegroundColor Red
            }
        }
    }

    # --- ЭТАП 3 ---
    Show-Section "3/9" "Глубокое сканирование JAR (Классы)"
    $patternsStrict = @("wurst", "meteorclient", "liquidbounce", "impact", "bleachhack", "killaura", "aimbot", "chestesp", "storageesp", "aristois", "sigma", "huzuni", "nodus", "konas", "rusherhack", "doomsday", "wildclient", "liminar")

    $foldersToScan = @()
    if (Test-Path $modsPath) { $foldersToScan += $modsPath }
    if (Test-Path $packsPath) { $foldersToScan += $packsPath }

    if ($foldersToScan.Count -eq 0) {
        Write-Host "  [i] Папки не найдены. Пропуск." -ForegroundColor DarkGray
    } else {
        $beforeCount = $global:totalFound
        $k = 0
        foreach ($folder in $foldersToScan) {
            $jarFiles = Get-ChildItem -Path $folder -Filter *.jar -File -ErrorAction SilentlyContinue
            foreach ($file in $jarFiles) {
                $k++
                Write-Progress -Activity "Поиск классов" -Status "Проверка: $($file.Name)"
                
                $foundInFile = @()
                try {
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
                    $classCounts = @{}
                    $classEntries = $zip.Entries | Where-Object { $_.FullName -match '\.class$' -and $_.Name -notmatch '(?i)package-info|module-info' }
                    foreach ($entry in $classEntries) {
                        $className = $entry.FullName -replace '\.class$','' -replace '/','.'
                        if (-not $classCounts.ContainsKey($className)) { $classCounts[$className] = 0 }
                        $classCounts[$className]++
                        foreach ($p in $patternsStrict) {
                            if ($className -match "(?i)$p") {
                                if ($p -eq "impact" -and $className -match "(?i)option|config|gui|screen|setting|menu|button") { continue }
                                $foundInFile += "Найден класс читов: '$p' ($className)"
                            }
                        }
                    }
                    foreach ($className in $classCounts.Keys) {
                        if ($classCounts[$className] -gt 10) {
                            $foundInFile += "Аномальное дублирование класса: '$className' встречается $($classCounts[$className]) раз"
                        }
                    }
                    $zip.Dispose()
                } catch {}

                if ($foundInFile.Count -gt 0) {
                    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor DarkRed
                    Write-Host "  │ [!!] Файл: $($file.Name)" -ForegroundColor Red
                    Write-Host "  ├─────────────────────────────────────────────────────────┤" -ForegroundColor DarkRed
                    foreach ($f in $foundInFile | Select-Object -Unique) {
                        Write-Host "  │  -> $f" -ForegroundColor DarkRed
                        $global:totalFound++
                    }
                    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor DarkRed
                }
            }
        }
        Write-Progress -Activity "Поиск классов" -Completed
        if ($global:totalFound -eq $beforeCount) { Write-Host "  [OK] Чисто. Внутри JAR читов нет." -ForegroundColor Green }
    }

    # --- ЭТАП 4 ---
    Show-Section "4/9" "Поиск твинк-аккаунтов"
    if (-not (Test-Path $logsPath)) { 
        Write-Host "  [i] Папка 'logs' не найдена. Пропуск." -ForegroundColor DarkGray 
    } else {
        $allNicks = [System.Collections.Generic.List[string]]::new()
        $l = 0
        foreach ($file in $logFiles) {
            $l++
            Write-Progress -Activity "Поиск ников" -Status "Файл $l из $($logFiles.Count)" -PercentComplete (($l / $logFiles.Count) * 100)
            $processUser = {
                param($line, $list)
                if ($line -match "Setting user:\s*([^\s,]+)") {
                    $nick = $matches[1].Trim()
                    if ($nick.Length -gt 0) { $list.Add($nick) }
                }
            }
            if ($file.Name -match '\.gz$') {
                try {
                    $inputStream = [System.IO.File]::OpenRead($file.FullName)
                    $gzipStream = New-Object System.IO.Compression.GzipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
                    $reader = New-Object System.IO.StreamReader($gzipStream)
                    while (($line = $reader.ReadLine()) -ne $null) { & $processUser $line $allNicks }
                    $reader.Close(); $gzipStream.Close(); $inputStream.Close()
                } catch {}
            } else {
                Get-Content -Path $file.FullName -ErrorAction SilentlyContinue | ForEach-Object { & $processUser $_ $allNicks }
            }
        }
        Write-Progress -Activity "Поиск ников" -Completed

        $launcherJson = Join-Path $env:APPDATA ".minecraft\launcher_profiles.json"
        if (Test-Path $launcherJson) {
            try {
                $json = Get-Content -Path $launcherJson -Raw | ConvertFrom-Json
                if ($json.authenticationDatabase) {
                    foreach ($acc in $json.authenticationDatabase.PSObject.Properties) {
                        if ($acc.Value.profiles) {
                            foreach ($prof in $acc.Value.profiles.PSObject.Properties) {
                                if ($prof.Value.displayName) { $allNicks.Add($prof.Value.displayName) }
                            }
                        }
                    }
                }
                if ($json.profiles) {
                    foreach ($prof in $json.profiles.PSObject.Properties) {
                        if ($prof.Value.name) { $allNicks.Add($prof.Value.name) }
                    }
                }
            } catch {}
        }

        $allNicks = $allNicks | Select-Object -Unique
        if ($allNicks.Count -eq 0) { Write-Host "  [OK] Чисто. Аккаунты не найдены." -ForegroundColor Green }
        elseif ($allNicks.Count -eq 1) { Write-Host "  [OK] Чисто. Один аккаунт: $($allNicks[0])" -ForegroundColor Green }
        else {
            Write-Host "  [!!] ВНИМАНИЕ! Разные аккаунты:" -ForegroundColor Red
            foreach ($nick in $allNicks) { $global:totalFound++; Write-Host "       -> $nick" -ForegroundColor Yellow }
        }
    }

    # --- ЭТАП 5 ---
    Show-Section "5/9" "Проверка конфигов"
    if (-not (Test-Path $configPath)) { 
        Write-Host "  [i] Папка 'config' не найдена. Пропуск." -ForegroundColor DarkGray 
    } else {
        $configFiles = @(Get-ChildItem -Path $configPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.json$|\.toml$|\.txt$|\.yml$|\.cfg$|\.properties$|\.json5$' })
        $configIssues = [System.Collections.Generic.List[object]]::new()
        
        foreach ($cFile in $configFiles) {
            $slug = Get-NormalizedSlug $cFile.Name
            $slugClean = $slug -replace '[-_]', ''
            foreach ($kw in $bannedKeywordsFilename) {
                $kwClean = $kw -replace '[-_]', ''
                if ($slugClean -eq $kwClean) {
                    $configIssues.Add([PSCustomObject]@{ File = $cFile.Name; Reason = "Имя содержит '$kw'"; Date = $cFile.LastWriteTime })
                    break
                }
            }
        }

        if ($configIssues.Count -eq 0) {
            Write-Host "  [OK] Чисто. В папке config подозрительных файлов нет." -ForegroundColor Green
        } else {
            foreach ($issue in $configIssues) {
                $global:totalFound++
                Write-Host "  [!!] КОНФИГ: $($issue.File)" -ForegroundColor Red
                Write-Host "       -> Причина: $($issue.Reason)" -ForegroundColor DarkRed
                if ($issue.Date -gt $dateThreshold) {
                    Write-Host "       [!] Изменен менее 14 дней назад ($($issue.Date))" -ForegroundColor Yellow
                }
            }
        }
    }

    # --- ЭТАП 6 ---
    Show-Section "6/9" "Системная криминалистика"
    $sysIssues = 0

    Write-Host "  [i] Анализ Prefetch..." -ForegroundColor DarkGray
    $prefetchPath = "C:\Windows\Prefetch"
    if ($isAdmin -and (Test-Path $prefetchPath)) {
        $pfFiles = Get-ChildItem -Path $prefetchPath -Filter *.pf -ErrorAction SilentlyContinue
        foreach ($pf in $pfFiles) {
            foreach ($kw in $bannedKeywordsFilename) {
                if ($pf.Name -match "(?i)$kw") {
                    Write-Host "  [!!] След в Prefetch: $($pf.Name)" -ForegroundColor Red
                    $sysIssues++; $global:totalFound++; break
                }
            }
        }
    } elseif (-not $isAdmin) {
        Write-Host "  [i] Prefetch: пропуск (нет прав)." -ForegroundColor DarkGray
    }

    Write-Host "  [i] Анализ Temp..." -ForegroundColor DarkGray
    $tempPath = $env:TEMP
    if (Test-Path $tempPath) {
        $tempFiles = Get-ChildItem -Path $tempPath -Recurse -Include *.exe, *.dll -ErrorAction SilentlyContinue | Select-Object -First 100
        foreach ($tf in $tempFiles) {
            if ($tf.Name -match "(?i)jnativehook|clicker|inject|cheat") {
                Write-Host "  [!!] Файл в Temp: $($tf.Name)" -ForegroundColor Red
                $sysIssues++; $global:totalFound++
            }
        }
    }

    Write-Host "  [i] Проверка Event Logs..." -ForegroundColor DarkGray
    if ($isAdmin) {
        try {
            $clearedLogs = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=1102} -MaxEvents 1 -ErrorAction SilentlyContinue
            if ($clearedLogs) {
                Write-Host "  [!!] Журнал Security очищен: $($clearedLogs.TimeCreated)" -ForegroundColor Red
                $sysIssues++; $global:totalFound++
            }
        } catch { Write-Host "  [i] Нет доступа к Security." -ForegroundColor DarkGray }
    } else {
        Write-Host "  [i] EventLogs: пропуск (нет прав)." -ForegroundColor DarkGray
    }

    Write-Host "  [i] Проверка корзины..." -ForegroundColor DarkGray
    $recycleBinPath = "C:\`$Recycle.Bin"
    if (Test-Path $recycleBinPath) {
        $binItems = Get-ChildItem -Path $recycleBinPath -Recurse -Force -ErrorAction SilentlyContinue
        if ($binItems.Count -eq 0) {
            $binFolder = Get-Item -Path $recycleBinPath -Force -ErrorAction SilentlyContinue
            if ($binFolder) { Write-Host "  [i] Корзина пуста. Изменение: $($binFolder.LastWriteTime)" -ForegroundColor Cyan }
        } else {
            $latestFile = $binItems | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestFile) {
                Write-Host "  [i] Последний удаленный: $($latestFile.Name)" -ForegroundColor Cyan
                Write-Host "      Время: $($latestFile.LastWriteTime)" -ForegroundColor Cyan
            }
        }
    }
    if ($sysIssues -eq 0 -and $isAdmin) { Write-Host "  [OK] Системных следов не обнаружено." -ForegroundColor Green }

    # --- ЭТАП 7 ---
    Show-Section "7/9" "Анализ Recent (Недавние файлы)"
    $recentPath = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
    if (Test-Path $recentPath) {
        $recentFiles = Get-ChildItem -Path $recentPath -Filter *.lnk -File -ErrorAction SilentlyContinue
        $recentFound = $false
        foreach ($rf in $recentFiles) {
            foreach ($kw in $bannedKeywordsFilename) {
                if ($rf.Name -match "(?i)$kw") {
                    Write-Host "  [!!] Найден ярлык: $($rf.Name)" -ForegroundColor Red
                    Write-Host "       Дата: $($rf.LastWriteTime)" -ForegroundColor DarkGray
                    $global:totalFound++; $recentFound = $true; break
                }
            }
        }
        if (-not $recentFound) { Write-Host "  [OK] В Recent нет подозрительных ярлыков." -ForegroundColor Green }
    } else { Write-Host "  [i] Папка Recent не найдена." -ForegroundColor DarkGray }

    # --- ЭТАП 8 ---
    Show-Section "8/9" "Анализ BAM (Запуски EXE)"
    $bamPath = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    if ($isAdmin -and (Test-Path $bamPath)) {
        $bamFound = $false
        try {
            $sidKeys = Get-ChildItem -Path $bamPath -ErrorAction SilentlyContinue
            foreach ($sid in $sidKeys) {
                $props = Get-ItemProperty -Path $sid.PSPath -ErrorAction SilentlyContinue
                if ($props) {
                    foreach ($prop in $props.PSObject.Properties) {
                        if ($prop.Name -match '(?i)\.exe|\.dll' -and $prop.Value -is [string]) {
                            $exePath = $prop.Name
                            foreach ($kw in $bannedKeywordsFilename) {
                                if ($exePath -match "(?i)$kw") {
                                    Write-Host "  [!!] BAM: Обнаружен запуск '$exePath'" -ForegroundColor Red
                                    $global:totalFound++; $bamFound = $true; break
                                }
                            }
                        }
                    }
                }
            }
        } catch {}
        if (-not $bamFound) { Write-Host "  [OK] В BAM подозрительных запусков не найдено." -ForegroundColor Green }
    } elseif (-not $isAdmin) {
        Write-Host "  [i] BAM: пропуск (нет прав)." -ForegroundColor DarkGray
    } else {
        Write-Host "  [i] Ключ BAM не найден." -ForegroundColor DarkGray
    }

    # --- ЭТАП 9 ---
    Show-Section "9/9" "Проверка Lunar Client и Downloads"
    $lunarPath = Join-Path $env:USERPROFILE ".lunarclient"
    if (Test-Path $lunarPath) {
        Write-Host "  [i] Обнаружен Lunar Client..." -ForegroundColor DarkGray
        $lunarProfiles = Get-ChildItem -Path (Join-Path $lunarPath "profiles") -Directory -ErrorAction SilentlyContinue
        foreach ($prof in $lunarProfiles) {
            $lunarMods = Join-Path $prof.FullName "mods"
            if (Test-Path $lunarMods) {
                $lunarJars = Get-ChildItem -Path $lunarMods -Filter *.jar -File -ErrorAction SilentlyContinue
                foreach ($lj in $lunarJars) {
                    $slug = Get-NormalizedSlug $lj.Name
                    $slugClean = $slug -replace '[-_]', ''
                    foreach ($kw in $bannedKeywordsFilename) {
                        $kwClean = $kw -replace '[-_]', ''
                        if ($slugClean -eq $kwClean) {
                            Write-Host "  [!!] Lunar-чит: $($lj.Name)" -ForegroundColor Red
                            $global:totalFound++
                            break
                        }
                    }
                }
            }
        }
    } else { Write-Host "  [OK] Lunar Client не обнаружен." -ForegroundColor Green }

    if (Test-Path $downloadsPath) {
        Write-Host "  [i] Проверка Downloads..." -ForegroundColor DarkGray
        $downFiles = Get-ChildItem -Path $downloadsPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.jar|\.exe|\.zip' }
        $downFound = $false
        foreach ($df in $downFiles) {
            $slug = Get-NormalizedSlug $df.Name
            $slugClean = $slug -replace '[-_]', ''
            foreach ($kw in $bannedKeywordsFilename) {
                $kwClean = $kw -replace '[-_]', ''
                if ($slugClean -eq $kwClean) {
                    Write-Host "  [!!] Скачанный чит: $($df.Name)" -ForegroundColor Red
                    $global:totalFound++; $downFound = $true; break
                }
            }
        }
        if (-not $downFound) { Write-Host "  [OK] В Downloads читов не найдено." -ForegroundColor Green }
    }
}
catch {
    $global:scanError = $_.Exception.Message
    Write-Host "`n  [!!] КРИТИЧЕСКАЯ ОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "       Стек: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}
finally {
    # --- ФИНАЛЬНЫЙ ОТЧЕТ ---
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    if ($global:scanError) {
        Write-Host "  ║  [!!] ПРОВЕРКА ПРЕРВАНА ОШИБКОЙ. Результат неполный." -ForegroundColor Red
    } elseif ($global:totalFound -eq 0) {
        Write-Host "  ║  [ OK ] СИСТЕМА ЧИСТА! Угроз не обнаружено." -ForegroundColor Green
    } else {
        Write-Host "  ║  [ !! ] ОБНАРУЖЕНО СОВПАДЕНИЙ: $global:totalFound" -ForegroundColor Red
    }
    if (-not $isAdmin) {
        Write-Host "  ║  [!] ОТЧЁТ НЕПОЛНЫЙ: запущено без прав администратора." -ForegroundColor Yellow
    }
    Write-Host "  ╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
    if ([Environment]::UserInteractive) {
        Write-Host "  [i] Нажмите Enter, чтобы закрыть окно..." -ForegroundColor DarkGray
        Read-Host
    }
}