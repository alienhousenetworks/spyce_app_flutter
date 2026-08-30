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

# Prefer a real JDK 17+ when system java is missing (common on macOS).
if ! command -v java >/dev/null 2>&1 || ! java -version >/dev/null 2>&1; then
  for candidate in \
    "${JAVA_HOME:-}" \
    "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
    "/opt/homebrew/opt/openjdk@17" \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  do
    if [[ -n "$candidate" && -x "$candidate/bin/java" ]]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
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
  --dart-define=ENABLE_SSL_PINNING="${ENABLE_SSL_PINNING:-false}" \
  --dart-define=SSL_FINGERPRINTS="${SSL_FINGERPRINTS:-}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://api01.spycenow.com}" \
  --dart-define=MAGIC_OTP="${MAGIC_OTP:-}"

APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_OUT="spyce.apk"
APK_LITE="spyce-lite.apk"

# Strip unused Amplify/JS source maps if they survived packaging.
if command -v zip >/dev/null 2>&1; then
  zip -d "$APK_SRC" \
    "*.map" \
    "*/*.map" \
    "*/*/*.map" \
    "*/*/*/*.map" \
    "*/*/*/*/*.map" \
    "*/*/*/*/*/*.map" \
    "*/*/*/*/*/*/*.map" \
    2>/dev/null || true
fi

cp -f "$APK_SRC" "$APK_OUT"
cp -f "$APK_SRC" "$APK_LITE"
cp -f "$APK_SRC" "../spyce.apk"
cp -f "$APK_SRC" "../spyce-lite.apk"

echo "=== Build complete ==="
ls -lh "$APK_SRC" "$APK_OUT" "$APK_LITE" "../spyce.apk"
echo "Symbols: $OUTPUT_DIR"
echo "Install: adb install -r $APK_OUT"
