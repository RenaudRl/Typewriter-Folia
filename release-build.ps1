# release-build.ps1 - Build complet Typewriter-Folia avec dossier release
# Exécuter depuis la racine du projet: .\release-build.ps1
# Pré-requis: Java 21, Flutter SDK accessible dans le PATH

$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " TYPEWRITER-FOLIA - BUILD RELEASE COMPLET" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan

# Vérifier Flutter
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    # Essayer de trouver Flutter dans le projet
    $localFlutter = Join-Path $root "flutter\bin\flutter.bat"
    if (Test-Path $localFlutter) {
        $env:PATH = (Join-Path $root "flutter\bin") + ";" + $env:PATH
        Write-Host "Flutter SDK local trouve: $localFlutter" -ForegroundColor DarkGray
    } else {
        Write-Host "ATTENTION: Flutter non trouve dans le PATH. Le panneau web ne sera pas inclus." -ForegroundColor Yellow
        Write-Host "Installez Flutter ou ajoutez-le au PATH pour inclure le panneau web." -ForegroundColor Yellow
    }
}

# Nettoyage
Write-Host "`n[0/4] Nettoyage..." -ForegroundColor Yellow
Remove-Item -Path (Join-Path $root "release") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $root "jars") -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "    Nettoyage OK" -ForegroundColor Green

# 1. Build Module Plugin
Write-Host "`n[1/4] Building Module Plugin..." -ForegroundColor Yellow
Set-Location (Join-Path $root "module-plugin")
.\gradlew.bat clean build -x test
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Module Plugin build FAILED!" -ForegroundColor Red
    Set-Location $root
    exit 1
}
Write-Host "    Module Plugin OK" -ForegroundColor Green

# 2. Build Flutter App (si disponible)
$flutterAvailable = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterAvailable) {
    Write-Host "`n[2/4] Building Flutter App (web)..." -ForegroundColor Yellow
    Set-Location (Join-Path $root "app")
    try {
        flutter clean 2>$null
        flutter pub get
        flutter build web
        Write-Host "    Flutter App OK" -ForegroundColor Green
    } catch {
        Write-Host "    Flutter App build FAILED (optionnel)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[2/4] Flutter non disponible - Skip..." -ForegroundColor DarkGray
}

# 3. Build Engine avec buildRelease (inclut le panneau Flutter si disponible)
Write-Host "`n[3/4] Building Engine (buildRelease)..." -ForegroundColor Yellow
Set-Location (Join-Path $root "engine")
.\gradlew.bat clean :engine-paper:buildRelease -x test
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Engine build FAILED!" -ForegroundColor Red
    Set-Location $root
    exit 1
}
Write-Host "    Engine OK" -ForegroundColor Green

# 4. Build toutes les extensions
Write-Host "`n[4/4] Building Extensions (buildReleaseAll)..." -ForegroundColor Yellow
Set-Location (Join-Path $root "extensions")
.\gradlew.bat clean buildReleaseAll -x test
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Extensions build FAILED!" -ForegroundColor Red
    Set-Location $root
    exit 1
}
Write-Host "    Extensions OK" -ForegroundColor Green

# Creer structure release
Write-Host "`nCreation du dossier release..." -ForegroundColor Yellow
Set-Location $root

$releaseDir = Join-Path $root "release"
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $releaseDir "engine") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $releaseDir "extensions") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $releaseDir "module-plugin") | Out-Null

# Copier engine
$engineJarsPath = Join-Path $root "jars\engine"
if (Test-Path $engineJarsPath) {
    Copy-Item -Path (Join-Path $engineJarsPath "*.jar") -Destination (Join-Path $releaseDir "engine") -Force
    Write-Host "    -> Engine JAR copie" -ForegroundColor DarkGray
}

# Copier extensions
$extJarsPath = Join-Path $root "jars\extensions"
if (Test-Path $extJarsPath) {
    Copy-Item -Path (Join-Path $extJarsPath "*.jar") -Destination (Join-Path $releaseDir "extensions") -Force
    $extCount = (Get-ChildItem (Join-Path $releaseDir "extensions") -Filter "*.jar").Count
    Write-Host "    -> $extCount extensions copiees" -ForegroundColor DarkGray
}

# Copier module-plugin
$modulePluginPath = Join-Path $root "module-plugin\build\libs"
if (Test-Path $modulePluginPath) {
    Copy-Item -Path (Join-Path $modulePluginPath "*.jar") -Destination (Join-Path $releaseDir "module-plugin") -Force -ErrorAction SilentlyContinue
    Write-Host "    -> Module Plugin copie" -ForegroundColor DarkGray
}

# Copier Flutter web (si disponible)
$webBuildPath = Join-Path $root "app\build\web"
if (Test-Path $webBuildPath) {
    Copy-Item -Path $webBuildPath -Destination (Join-Path $releaseDir "web") -Recurse -Force
    Write-Host "    -> Flutter Web Panel copie" -ForegroundColor DarkGray
}

# Copier version.txt
$versionFile = Join-Path $root "version.txt"
if (Test-Path $versionFile) {
    Copy-Item -Path $versionFile -Destination (Join-Path $releaseDir "version.txt") -Force
    $version = Get-Content $versionFile -Raw
    Write-Host "    -> Version: $($version.Trim())" -ForegroundColor DarkGray
}

# Resume
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " BUILD COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nStructure du dossier release:" -ForegroundColor White
Write-Host "  $releaseDir\" -ForegroundColor Yellow

# Lister le contenu
Get-ChildItem $releaseDir -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Replace($releaseDir, "").TrimStart("\")
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "    $relativePath ($sizeMB MB)" -ForegroundColor DarkGray
}

Write-Host "`n>> Copiez le contenu de 'release\' vers votre serveur!" -ForegroundColor Magenta
Write-Host ""
