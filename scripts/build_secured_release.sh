#!/usr/bin/env bash
# ==============================================================================
# SPYCE Secured Production Release Build Script
# Enforces Flutter Dart obfuscation, debug symbol splitting, and environment definitions.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

OUTPUT_DIR="build/app/outputs/symbols"
mkdir -p "$OUTPUT_DIR"

echo "=== Running Flutter Clean & Pub Get ==="
flutter clean
flutter pub get

echo "=== Building Secured Obfuscated Release APK ==="
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info="$OUTPUT_DIR" \
  --dart-define=ENABLE_SSL_PINNING="${ENABLE_SSL_PINNING:-true}" \
  --dart-define=SSL_FINGERPRINTS="${SSL_FINGERPRINTS:-}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://testapi.spycenow.com}"

echo "=== Build Complete ==="
echo "Secured APK generated at: build/app/outputs/flutter-apk/app-release.apk"
echo "Obfuscation symbol files saved at: $OUTPUT_DIR"
