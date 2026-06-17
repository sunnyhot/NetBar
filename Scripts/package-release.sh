#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetBar"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.app.zip"

cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/build-app.sh"
"$ROOT_DIR/Scripts/verify-release-app.sh" "$APP_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "$ZIP_PATH"
