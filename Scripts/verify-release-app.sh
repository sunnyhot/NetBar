#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-build/NetBar.app}"
EXECUTABLE="$APP_DIR/Contents/MacOS/NetBar"
EXPECTED_ARCHS="${NETBAR_EXPECT_ARCHS:-}"
VERIFY_STDOUT="$(mktemp /tmp/netbar-codesign-verify.out.XXXXXX)"
VERIFY_STDERR="$(mktemp /tmp/netbar-codesign-verify.err.XXXXXX)"
trap 'rm -f "$VERIFY_STDOUT" "$VERIFY_STDERR"' EXIT

if [ ! -d "$APP_DIR" ]; then
    echo "error: app bundle not found: $APP_DIR" >&2
    exit 1
fi

if [ ! -x "$EXECUTABLE" ]; then
    echo "error: executable not found: $EXECUTABLE" >&2
    exit 1
fi

if [ -n "$EXPECTED_ARCHS" ]; then
    ARCHS="$(lipo -archs "$EXECUTABLE")"
    for EXPECTED_ARCH in $EXPECTED_ARCHS; do
        if [[ " $ARCHS " != *" $EXPECTED_ARCH "* ]]; then
            echo "error: expected executable architecture $EXPECTED_ARCH, got: $ARCHS" >&2
            exit 1
        fi
    done
    echo "arch: $ARCHS"
fi

if codesign --verify --deep --strict --verbose=2 "$APP_DIR" >"$VERIFY_STDOUT" 2>"$VERIFY_STDERR"; then
    echo "codesign: full app bundle signature verified"
    exit 0
fi

SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_DIR" 2>&1 || true)"

if grep -q "linker-signed" <<<"$SIGNATURE_DETAILS" && grep -q "Signature=adhoc" <<<"$SIGNATURE_DETAILS"; then
    echo "codesign: strict bundle verification did not pass; release app uses SwiftPM linker-signed executable"
    echo "$SIGNATURE_DETAILS" | awk '/Identifier=|flags=|Page size=|Signature=|Info.plist=|Sealed Resources=/'
    exit 0
fi

echo "error: app is neither a strict-valid signed bundle nor a SwiftPM linker-signed release app" >&2
cat "$VERIFY_STDERR" >&2
echo "$SIGNATURE_DETAILS" >&2
exit 1
