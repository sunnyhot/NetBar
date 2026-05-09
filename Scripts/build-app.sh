#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetBar"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/.build/swiftpm-home"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export HOME="$ROOT_DIR/.build/swiftpm-home"

swift build --disable-sandbox -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/$CONFIGURATION/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

chmod +x "$MACOS_DIR/$APP_NAME"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
