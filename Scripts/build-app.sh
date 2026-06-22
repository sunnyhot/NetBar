#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetBar"
CONFIGURATION="${CONFIGURATION:-release}"
NETBAR_BUILD_UNIVERSAL="${NETBAR_BUILD_UNIVERSAL:-0}"
if [ -z "${NETBAR_CODESIGN_APP+x}" ]; then
    if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
        NETBAR_CODESIGN_APP=1
    else
        NETBAR_CODESIGN_APP=0
    fi
fi
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/.build/swiftpm-home"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export HOME="$ROOT_DIR/.build/swiftpm-home"

SWIFT_BUILD_ARGS=(swift build --disable-sandbox -c "$CONFIGURATION")
if [ "$NETBAR_BUILD_UNIVERSAL" = "1" ]; then
    SWIFT_BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

"${SWIFT_BUILD_ARGS[@]}"

PRODUCT_PATH="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
if [ "$NETBAR_BUILD_UNIVERSAL" = "1" ]; then
    case "$CONFIGURATION" in
        release) SWIFTPM_CONFIGURATION_DIR="Release" ;;
        debug) SWIFTPM_CONFIGURATION_DIR="Debug" ;;
        *)
            echo "error: universal build only supports debug or release configuration" >&2
            exit 1
            ;;
    esac

    UNIVERSAL_PRODUCT_PATH="$ROOT_DIR/.build/apple/Products/$SWIFTPM_CONFIGURATION_DIR/$APP_NAME"
    if [ -x "$UNIVERSAL_PRODUCT_PATH" ]; then
        PRODUCT_PATH="$UNIVERSAL_PRODUCT_PATH"
    fi
fi

if [ ! -x "$PRODUCT_PATH" ]; then
    echo "error: built executable not found: $PRODUCT_PATH" >&2
    exit 1
fi

if [ "$NETBAR_BUILD_UNIVERSAL" = "1" ]; then
    ARCHS="$(lipo -archs "$PRODUCT_PATH")"
    if [[ " $ARCHS " != *" arm64 "* || " $ARCHS " != *" x86_64 "* ]]; then
        echo "error: expected universal executable with arm64 and x86_64, got: $ARCHS" >&2
        exit 1
    fi
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PRODUCT_PATH" "$MACOS_DIR/$APP_NAME"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Copy RunCat animation resources
if [ -d "Resources/RunCat" ]; then
    cp -R "Resources/RunCat" "$RESOURCES_DIR/RunCat"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

if [ "$NETBAR_CODESIGN_APP" = "1" ]; then
    CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
    ENTITLEMENTS="${NETBAR_CODESIGN_ENTITLEMENTS-$ROOT_DIR/Resources/NetBar.entitlements}"
    # Preserve the 4K CodeDirectory page size produced by SwiftPM's linker
    # signature. On newer macOS builds, re-signing this small menu-bar app with
    # the codesign default 16K page size can pass verification but be killed at launch.
    CODESIGN_PAGE_SIZE=(--pagesize 4096)
    CODESIGN_FLAGS=(--force --deep --sign "$CODESIGN_IDENTITY")
    if [ "${NETBAR_HARDENED_RUNTIME:-0}" = "1" ]; then
        CODESIGN_FLAGS+=(--options runtime)
    fi
    if [ "$CODESIGN_IDENTITY" != "-" ]; then
        CODESIGN_FLAGS+=(--timestamp)
    fi

    if [ -n "$ENTITLEMENTS" ] && [ -f "$ENTITLEMENTS" ]; then
        CODESIGN_FLAGS+=(--entitlements "$ENTITLEMENTS")
    fi
    CODESIGN_FLAGS+=("${CODESIGN_PAGE_SIZE[@]}")

    if command -v codesign >/dev/null 2>&1; then
        if ! codesign "${CODESIGN_FLAGS[@]}" "$APP_DIR" >/dev/null 2>&1; then
            if [ "$CODESIGN_IDENTITY" != "-" ]; then
                echo "error: codesign failed for identity: $CODESIGN_IDENTITY" >&2
                exit 1
            fi
            if ! codesign --force --deep --sign - "${CODESIGN_PAGE_SIZE[@]}" "$APP_DIR" >/dev/null 2>&1; then
                if [ "${ALLOW_UNSIGNED_BUILD:-0}" = "1" ]; then
                    echo "warning: codesign failed; continuing because ALLOW_UNSIGNED_BUILD=1" >&2
                else
                    echo "error: codesign failed; set ALLOW_UNSIGNED_BUILD=1 to keep an unsigned local build" >&2
                    exit 1
                fi
            fi
        fi
    fi
else
    echo "Skipping bundle codesign; preserving SwiftPM linker-signed executable"
fi

echo "$APP_DIR"
