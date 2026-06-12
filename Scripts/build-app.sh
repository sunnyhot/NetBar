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

# Copy RunCat animation resources
if [ -d "Resources/RunCat" ]; then
    cp -R "Resources/RunCat" "$RESOURCES_DIR/RunCat"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

ENTITLEMENTS="$ROOT_DIR/Resources/NetBar.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    CODESIGN_FLAGS=(--force --deep --sign - --entitlements "$ENTITLEMENTS")
else
    CODESIGN_FLAGS=(--force --deep --sign -)
fi

if command -v codesign >/dev/null 2>&1; then
    if ! codesign "${CODESIGN_FLAGS[@]}" "$APP_DIR" >/dev/null 2>&1; then
        if ! codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1; then
            if [ "${ALLOW_UNSIGNED_BUILD:-0}" = "1" ]; then
                echo "warning: codesign failed; continuing because ALLOW_UNSIGNED_BUILD=1" >&2
            else
                echo "error: codesign failed; set ALLOW_UNSIGNED_BUILD=1 to keep an unsigned local build" >&2
                exit 1
            fi
        fi
    fi
fi

echo "$APP_DIR"
