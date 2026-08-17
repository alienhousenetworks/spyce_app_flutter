#!/usr/bin/env bash
# ==============================================================================
# SPYCE lighter Android APK (arm64-only + R8 minify + Dart obfuscation)
#
# Size wins vs universal fat APK:
#   - target-platform android-arm64 only (modern phones)
#   - Gradle abiFilters + jni excludes already drop 32-bit / x86
#   - release minifyEnabled + shrinkResources
#   - Flutter --obfuscate + tree-shaken icons
#
# Usage:
#   ./scripts/build_lite_apk.sh
#   API_BASE_URL=https://api.example.com ./scripts/build_lite_apk.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Prefer Android Studio JBR when system java is missing (common on macOS).
if ! command -v java >/dev/null 2>&1 || ! java -version >/dev/null 2>&1; then
  AS_JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [[ -x "$AS_JBR/bin/java" ]]; then
    export JAVA_HOME="$AS_JBR"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

OUTPUT_DIR="build/app/outputs/symbols"
mkdir -p "$OUTPUT_DIR"

echo "=== Flutter pub get ==="
flutter pub get

echo "=== Building lighter arm64-only release APK ==="
flutter build apk \
  --release \
  --target-platform android-arm64 \
  --obfuscate \
  --split-debug-info="$OUTPUT_DIR" \
  --dart-define=ENABLE_SSL_PINNING="${ENABLE_SSL_PINNING:-true}" \
  --dart-define=SSL_FINGERPRINTS="${SSL_FINGERPRINTS:-}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://api01.spycenow.com}"

APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_OUT="spyce-lite.apk"
cp -f "$APK_SRC" "$APK_OUT"

echo "=== Build complete ==="
ls -lh "$APK_SRC" "$APK_OUT"
echo "Symbols: $OUTPUT_DIR"
echo "Install: adb install -r $APK_OUT"
