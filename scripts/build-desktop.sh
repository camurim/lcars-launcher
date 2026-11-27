#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="${ROOT_DIR}/desktop-agent"

echo "==> [LCARS Desktop Agent] Iniciando build em ${DESKTOP_DIR}"

if ! command -v npm >/dev/null 2>&1; then
  echo "Erro: 'npm' não encontrado no PATH." >&2
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "Erro: 'cargo' (Rust) não encontrado no PATH." >&2
  exit 1
fi

cd "${DESKTOP_DIR}"

if [ ! -d "node_modules" ]; then
  echo "==> Instalando dependências Node.js..."
  npm install
fi

echo "==> Compilando frontend (TypeScript + Tailwind + Vite)..."
npm run build

if [ "${1:-}" = "--check-only" ]; then
  echo "==> Executando cargo check + cargo test..."
  (cd src-tauri && cargo check && cargo test)
  echo "==> [LCARS Desktop Agent] Verificação concluída com sucesso."
  exit 0
fi

echo "==> Gerando binário/bundle Tauri v2 (release)..."
npm run tauri build

echo "==> [LCARS Desktop Agent] Build concluído! Artefatos em: ${DESKTOP_DIR}/src-tauri/target/release/bundle"
