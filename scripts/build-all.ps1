param(
    [ValidateSet("apk", "appbundle", "web")]
    [string]$MobileTarget = "apk"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Yellow
Write-Host "  LCARS Launcher - Build Completo (Mobile -> Desktop)" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow

& (Join-Path $PSScriptRoot "build-mobile.ps1") -Target $MobileTarget
& (Join-Path $PSScriptRoot "build-desktop.ps1")

Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Build completo finalizado com sucesso!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
