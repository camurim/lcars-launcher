#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="${ROOT_DIR}/desktop-agent"
TAURI_DIR="${DESKTOP_DIR}/src-tauri"
ICONS_SRC_DIR="${TAURI_DIR}/icons"

APP_ID="lcars-desktop-agent"
APP_NAME="Sci-Fi Deck Agent"
APP_GENERIC_NAME="LCARS Launcher Desktop Agent"
BIN_NAME="lcars-desktop-agent"
BIN_SRC="${TAURI_DIR}/target/release/${BIN_NAME}"

SCOPE=""
ACTION="install"
FORCE_BUILD=0
NO_BUILD=0
AUTOSTART=""
ASSUME_YES=0
CUSTOM_PREFIX=""

print_usage() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Instala ou desinstala o ${APP_NAME} (${BIN_NAME}) no Linux, copiando o binário,
ícones (hicolor) e atalho de aplicativo (.desktop), com suporte opcional a autostart.

Opções:
  --user            Instala/remove ao nível do usuário (~/.local) [sem sudo]
  --system          Instala/remove ao nível do sistema (/usr/local) [requer sudo/root]
  --prefix DIR      Define um prefixo customizado (ex.: /opt/lcars ou /usr)
  --build           Força a compilação release antes de instalar
  --no-build        Não compila; falha se o binário release ainda não existir
  --autostart       Cria atalho de inicialização automática com a sessão
  --no-autostart    Não cria atalho de inicialização automática
  --uninstall       Remove os arquivos instalados no escopo escolhido
  -y, --yes         Modo não-interativo (aceita padrões sem perguntar)
  -h, --help        Exibe esta ajuda

Exemplos:
  $(basename "$0")                         # Modo interativo (pergunta usuário vs sistema)
  $(basename "$0") --user --autostart      # Instala apenas para o usuário atual com autostart
  $(basename "$0") --system                # Instala para todos os usuários do sistema
  $(basename "$0") --uninstall --user      # Remove a instalação do usuário atual
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      SCOPE="user"
      shift
      ;;
    --system)
      SCOPE="system"
      shift
      ;;
    --prefix)
      if [ $# -lt 2 ]; then
        echo "Erro: --prefix requer um caminho de diretório." >&2
        exit 1
      fi
      CUSTOM_PREFIX="$2"
      shift 2
      ;;
    --build)
      FORCE_BUILD=1
      shift
      ;;
    --no-build)
      NO_BUILD=1
      shift
      ;;
    --autostart)
      AUTOSTART="yes"
      shift
      ;;
    --no-autostart)
      AUTOSTART="no"
      shift
      ;;
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Erro: opção desconhecida '$1'." >&2
      echo "Use --help para ver as opções disponíveis." >&2
      exit 1
      ;;
  esac
done

if [ "${FORCE_BUILD}" -eq 1 ] && [ "${NO_BUILD}" -eq 1 ]; then
  echo "Erro: --build e --no-build não podem ser usados juntos." >&2
  exit 1
fi

is_interactive() {
  [ -t 0 ] && [ "${ASSUME_YES}" -eq 0 ]
}

# Seleção interativa do escopo se não informado por flag
if [ -z "${SCOPE}" ]; then
  if [ -n "${CUSTOM_PREFIX}" ]; then
    SCOPE="system"
  elif is_interactive; then
    echo "========================================================"
    echo "  ${APP_NAME} — Instalador Linux"
    echo "========================================================"
    echo ""
    if [ "${ACTION}" = "uninstall" ]; then
      echo "Selecione o escopo da desinstalação:"
    else
      echo "Selecione o nível de instalação:"
    fi
    echo "  1) Usuário atual (~/.local) — não requer privilégios de administrador"
    echo "  2) Sistema (/usr/local)     — disponível para todos os usuários (requer sudo)"
    echo ""
    while true; do
      read -r -p "Opção [1/2] (padrão: 1): " choice
      case "${choice:-1}" in
        1|u|U|user|usuario)
          SCOPE="user"
          break
          ;;
        2|s|S|system|sistema)
          SCOPE="system"
          break
          ;;
        *)
          echo "Opção inválida. Digite 1 para usuário ou 2 para sistema."
          ;;
      esac
    done
  else
    SCOPE="user"
  fi
fi

# Define diretórios de destino conforme o escopo
if [ "${SCOPE}" = "user" ]; then
  if [ "${EUID}" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    echo "Aviso: executando instalação de usuário como root via sudo." >&2
    echo "       Recomenda-se rodar sem sudo para instalação --user." >&2
  fi
  PREFIX="${CUSTOM_PREFIX:-${HOME}/.local}"
  BIN_DIR="${PREFIX}/bin"
  DATA_DIR="${PREFIX}/share"
  APPS_DIR="${DATA_DIR}/applications"
  ICONS_DIR="${DATA_DIR}/icons/hicolor"
  AUTOSTART_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
  NEED_SUDO=0
else
  PREFIX="${CUSTOM_PREFIX:-/usr/local}"
  BIN_DIR="${PREFIX}/bin"
  DATA_DIR="${PREFIX}/share"
  APPS_DIR="${DATA_DIR}/applications"
  ICONS_DIR="${DATA_DIR}/icons/hicolor"
  AUTOSTART_DIR="/etc/xdg/autostart"
  if [ "${EUID}" -ne 0 ]; then
    NEED_SUDO=1
  else
    NEED_SUDO=0
  fi
fi

run_priv() {
  if [ "${NEED_SUDO}" -eq 1 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
      echo "Erro: privilégios de root são necessários para instalação em ${PREFIX}, mas 'sudo' não foi encontrado." >&2
      echo "Execute este script como root." >&2
      exit 1
    fi
    sudo "$@"
  else
    "$@"
  fi
}

update_desktop_caches() {
  if command -v update-desktop-database >/dev/null 2>&1 && [ -d "${APPS_DIR}" ]; then
    run_priv update-desktop-database -q "${APPS_DIR}" 2>/dev/null || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -d "${ICONS_DIR}" ]; then
    run_priv gtk-update-icon-cache -f -t -q "${ICONS_DIR}" 2>/dev/null || true
  fi
}

build_desktop_binary() {
  if [ "${EUID}" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    echo "Erro: evite compilar como root. Rode o script sem 'sudo' — o instalador solicitará sudo apenas na etapa de cópia para o sistema." >&2
    exit 1
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "Erro: 'npm' não encontrado no PATH." >&2
    exit 1
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "Erro: 'cargo' (Rust) não encontrado no PATH." >&2
    exit 1
  fi

  echo "==> Compilando ${APP_NAME} (release)..."
  (
    cd "${DESKTOP_DIR}"
    if [ ! -d "node_modules" ]; then
      echo "==> Instalando dependências Node.js..."
      npm install
    fi
    echo "==> Gerando binário Tauri v2 (release, sem empacotamento)..."
    npm run tauri build -- --no-bundle
  )
}

do_uninstall() {
  echo "==> Removendo ${APP_NAME} (escopo: ${SCOPE}, prefixo: ${PREFIX})..."

  if [ "${NEED_SUDO}" -eq 1 ]; then
    echo "==> Solicitando permissão administrativa (sudo) para remover arquivos do sistema..."
    sudo -v
  fi

  local removed=0
  local targets=(
    "${BIN_DIR}/${BIN_NAME}"
    "${APPS_DIR}/${APP_ID}.desktop"
    "${AUTOSTART_DIR}/${APP_ID}.desktop"
    "${ICONS_DIR}/32x32/apps/${APP_ID}.png"
    "${ICONS_DIR}/128x128/apps/${APP_ID}.png"
    "${ICONS_DIR}/256x256/apps/${APP_ID}.png"
    "${ICONS_DIR}/512x512/apps/${APP_ID}.png"
  )

  for target in "${targets[@]}"; do
    if [ -e "${target}" ] || [ -L "${target}" ]; then
      run_priv rm -f "${target}"
      echo "  [removido] ${target}"
      removed=1
    fi
  done

  update_desktop_caches

  if [ "${removed}" -eq 0 ]; then
    echo "==> Nenhum arquivo instalado encontrado em ${PREFIX}."
  else
    echo "==> Desinstalação concluída com sucesso."
    echo "    Nota: os dados/configurações do usuário em ~/.local/share/lcars-launcher foram preservados."
  fi
}

generate_desktop_file() {
  local out_file="$1"
  local is_autostart="${2:-0}"

  cat > "${out_file}" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=${APP_NAME}
GenericName=${APP_GENERIC_NAME}
Comment=Painel de controle remoto e telemetria LCARS para desktop
Comment[en]=LCARS remote control and desktop telemetry agent
Exec=${BIN_DIR}/${BIN_NAME}
TryExec=${BIN_DIR}/${BIN_NAME}
Icon=${APP_ID}
Terminal=false
Categories=Utility;RemoteAccess;
Keywords=LCARS;Sci-Fi;Deck;Remote;Telemetry;Launcher;
StartupNotify=false
StartupWMClass=${BIN_NAME}
EOF

  if [ "${is_autostart}" -eq 1 ]; then
    echo "X-GNOME-Autostart-enabled=true" >> "${out_file}"
  fi
}

do_install() {
  # Pergunta sobre autostart no modo interativo se não informado por flag
  if [ -z "${AUTOSTART}" ]; then
    if is_interactive; then
      read -r -p "Iniciar ${APP_NAME} automaticamente ao fazer login? [s/N]: " ans
      case "${ans:-n}" in
        s|S|sim|SIM|y|Y|yes|YES)
          AUTOSTART="yes"
          ;;
        *)
          AUTOSTART="no"
          ;;
      esac
    else
      AUTOSTART="no"
    fi
  fi

  # Verifica se precisa compilar o binário
  if [ "${FORCE_BUILD}" -eq 1 ]; then
    build_desktop_binary
  elif [ ! -x "${BIN_SRC}" ]; then
    if [ "${NO_BUILD}" -eq 1 ]; then
      echo "Erro: binário não encontrado em ${BIN_SRC} e --no-build foi especificado." >&2
      echo "Compile antes com './scripts/build-desktop.sh' ou remova --no-build." >&2
      exit 1
    fi
    if is_interactive; then
      echo "Binário release não encontrado em: ${BIN_SRC}"
      read -r -p "Deseja compilar o ${APP_NAME} agora? [S/n]: " build_ans
      case "${build_ans:-s}" in
        s|S|sim|SIM|y|Y|yes|YES)
          build_desktop_binary
          ;;
        *)
          echo "Instalação cancelada. Compile antes com './scripts/build-desktop.sh'." >&2
          exit 1
          ;;
      esac
    else
      build_desktop_binary
    fi
  fi

  if [ ! -x "${BIN_SRC}" ]; then
    echo "Erro: binário compilado não encontrado em ${BIN_SRC}." >&2
    exit 1
  fi

  echo ""
  echo "==> Instalando ${APP_NAME}..."
  echo "    Escopo:    ${SCOPE}"
  echo "    Binário:   ${BIN_DIR}/${BIN_NAME}"
  echo "    Atalho:    ${APPS_DIR}/${APP_ID}.desktop"
  echo "    Ícones:    ${ICONS_DIR}/<tam>/apps/${APP_ID}.png"
  if [ "${AUTOSTART}" = "yes" ]; then
    echo "    Autostart: ${AUTOSTART_DIR}/${APP_ID}.desktop"
  fi

  if [ "${NEED_SUDO}" -eq 1 ]; then
    echo "==> Solicitando permissão administrativa (sudo) para instalar em ${PREFIX}..."
    sudo -v
  fi

  # 1. Instala o binário
  run_priv install -d -m 0755 "${BIN_DIR}"
  run_priv install -m 0755 "${BIN_SRC}" "${BIN_DIR}/${BIN_NAME}"

  # 2. Instala os ícones no tema hicolor
  declare -A ICON_MAP=(
    ["32x32"]="32x32.png"
    ["128x128"]="128x128.png"
    ["256x256"]="128x128@2x.png"
    ["512x512"]="icon.png"
  )

  for size in 32x32 128x128 256x256 512x512; do
    src_icon="${ICONS_SRC_DIR}/${ICON_MAP[${size}]}"
    if [ -f "${src_icon}" ]; then
      dest_dir="${ICONS_DIR}/${size}/apps"
      run_priv install -d -m 0755 "${dest_dir}"
      run_priv install -m 0644 "${src_icon}" "${dest_dir}/${APP_ID}.png"
    fi
  done

  # 3. Gera e instala o arquivo .desktop
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT

  DESKTOP_TMP="${TMP_DIR}/${APP_ID}.desktop"
  generate_desktop_file "${DESKTOP_TMP}" 0

  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "${DESKTOP_TMP}"
  fi

  run_priv install -d -m 0755 "${APPS_DIR}"
  run_priv install -m 0644 "${DESKTOP_TMP}" "${APPS_DIR}/${APP_ID}.desktop"

  # 4. Opcionalmente instala o atalho de autostart
  if [ "${AUTOSTART}" = "yes" ]; then
    AUTOSTART_TMP="${TMP_DIR}/${APP_ID}-autostart.desktop"
    generate_desktop_file "${AUTOSTART_TMP}" 1
    run_priv install -d -m 0755 "${AUTOSTART_DIR}"
    run_priv install -m 0644 "${AUTOSTART_TMP}" "${AUTOSTART_DIR}/${APP_ID}.desktop"
  fi

  # 5. Atualiza caches do ambiente desktop
  update_desktop_caches

  echo ""
  echo "==> ${APP_NAME} instalado com sucesso!"
  echo "    Você já pode iniciá-lo pelo menu de aplicativos ou executando:"
  echo "      ${BIN_DIR}/${BIN_NAME}"

  if [ "${SCOPE}" = "user" ]; then
    case ":${PATH}:" in
      *":${BIN_DIR}:"*) ;;
      *)
        echo ""
        echo "Aviso: '${BIN_DIR}' não está no seu PATH atual."
        echo "       O atalho no menu de aplicativos funcionará normalmente, mas para executar"
        echo "       '${BIN_NAME}' pelo terminal, adicione ao seu ~/.bashrc ou ~/.zshrc:"
        echo "         export PATH=\"${BIN_DIR}:\${PATH}\""
        ;;
    esac
  fi
}

if [ "${ACTION}" = "uninstall" ]; then
  do_uninstall
else
  do_install
fi
