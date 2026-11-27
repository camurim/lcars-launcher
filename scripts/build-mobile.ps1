param(
    [ValidateSet("apk", "appbundle", "web")]
    [string]$Target = "apk"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$MobileDir = Join-Path $RootDir "mobile-client"

Write-Host "==> [LCARS Mobile Client] Iniciando build ($Target) em $MobileDir" -ForegroundColor Cyan

Push-Location $MobileDir
try {
    if (($Target -eq "apk" -or $Target -eq "appbundle") -and -not (Test-Path "android")) {
        Write-Host "==> Gerando diretório nativo android/..."
        flutter create . --org dev.carlosamorim.lcars --platforms=android
        if (Test-Path "test/widget_test.dart") { Remove-Item "test/widget_test.dart" -Force }
    }

    flutter pub get
    flutter analyze
    flutter test

    switch ($Target) {
        "apk" {
            flutter build apk --release
            Write-Host "==> APK: $MobileDir\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
        }
        "appbundle" {
            flutter build appbundle --release
            Write-Host "==> AAB: $MobileDir\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
        }
        "web" {
            flutter build web --release
            Write-Host "==> Web: $MobileDir\build\web" -ForegroundColor Green
        }
    }
} finally {
    Pop-Location
}
