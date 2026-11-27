#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/mobile-client"
TARGET="${1:-apk}" # Opções: apk | appbundle | ios | web

echo "==> [LCARS Mobile Client] Iniciando build (${TARGET}) em ${MOBILE_DIR}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Erro: 'flutter' não encontrado no PATH. Instale o Flutter SDK primeiro." >&2
  exit 1
fi

cd "${MOBILE_DIR}"

# Gera scaffolding nativo caso ainda não exista no repositório
if { [ "${TARGET}" = "apk" ] || [ "${TARGET}" = "appbundle" ]; } && [ ! -d "android" ]; then
  echo "==> Gerando diretório nativo android/..."
  flutter create . --org dev.carlosamorim.lcars --platforms=android
  rm -f test/widget_test.dart
elif [ "${TARGET}" = "ios" ] && [ ! -d "ios" ]; then
  echo "==> Gerando diretório nativo ios/..."
  flutter create . --org dev.carlosamorim.lcars --platforms=ios
  rm -f test/widget_test.dart
fi

echo "==> Baixando dependências Flutter..."
flutter pub get

echo "==> Validando análise estática e testes..."
flutter analyze
flutter test

echo "==> Gerando build release (${TARGET})..."
case "${TARGET}" in
  apk)
    flutter build apk --release
    echo "==> APK gerado em: ${MOBILE_DIR}/build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle)
    flutter build appbundle --release
    echo "==> AAB gerado em: ${MOBILE_DIR}/build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    flutter build ios --release --no-codesign
    echo "==> Build iOS concluído em: ${MOBILE_DIR}/build/ios/iphoneos"
    ;;
  web)
    flutter build web --release
    echo "==> Build Web concluído em: ${MOBILE_DIR}/build/web"
    ;;
  *)
    echo "Alvo inválido: '${TARGET}'. Use: apk | appbundle | ios | web" >&2
    exit 1
    ;;
esac
