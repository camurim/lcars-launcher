#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_TARGET="${1:-apk}"

echo "========================================================"
echo "  LCARS Launcher — Build Completo (Mobile -> Desktop)"
echo "========================================================"

"${SCRIPT_DIR}/build-mobile.sh" "${MOBILE_TARGET}"
echo ""
"${SCRIPT_DIR}/build-desktop.sh"

echo "========================================================"
echo "  Build completo finalizado com sucesso!"
echo "========================================================"
