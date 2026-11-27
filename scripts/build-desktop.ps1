param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$DesktopDir = Join-Path $RootDir "desktop-agent"

Write-Host "==> [LCARS Desktop Agent] Iniciando build em $DesktopDir" -ForegroundColor Cyan

Push-Location $DesktopDir
try {
    if (-not (Test-Path "node_modules")) {
        Write-Host "==> Instalando dependências Node.js..."
        npm install
    }

    Write-Host "==> Compilando frontend (TypeScript + Tailwind + Vite)..."
    npm run build

    if ($CheckOnly) {
        Push-Location "src-tauri"
        try {
            cargo check
            cargo test
        } finally {
            Pop-Location
        }
        Write-Host "==> [LCARS Desktop Agent] Verificação concluída." -ForegroundColor Green
        exit 0
    }

    Write-Host "==> Gerando binário/bundle Tauri v2 (release)..."
    npm run tauri build
    Write-Host "==> Artefatos em: $DesktopDir\src-tauri\target\release\bundle" -ForegroundColor Green
} finally {
    Pop-Location
}
