#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"
case "$CONFIG" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 2;; esac
if [[ "$(uname -s)" != Darwin ]]; then
    echo "The GUI requires macOS 15+ and a Swift 6 Apple toolchain. Core tests/CLI also run on Linux." >&2
    exit 2
fi
cd "$ROOT"
SWIFT="${SWIFT:-$(xcrun --find swift)}"
"$SWIFT" build -c "$CONFIG" --product SidecarCompare -Xswiftc -warnings-as-errors
BIN_DIR="$("$SWIFT" build -c "$CONFIG" --show-bin-path)"
[[ ! -L "$ROOT/dist" ]] || { echo "Refusing a symlinked dist directory." >&2; exit 2; }
mkdir -p "$ROOT/dist"
STAGE="$(mktemp -d "$ROOT/dist/.stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/SidecarCompare.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/SidecarCompare" "$APP/Contents/MacOS/SidecarCompare"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
# Reuse the accepted Icon Composer compilation; keep the layered .icon source
# in Packaging/Icon as the editable authority.
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/Packaging/Icon/Compiled/Assets.car" "$APP/Contents/Resources/Assets.car"
cp "$ROOT/Packaging/Icon/Compiled/SidecarCompare.icns" "$APP/Contents/Resources/SidecarCompare.icns"
chmod +x "$APP/Contents/MacOS/SidecarCompare"
if [[ "$CONFIG" == debug ]]; then
    mkdir -p "$APP/Contents/Resources/NativeAcceptance/Folder"
    cp "$ROOT/Fixtures/mri-baseline.json" "$APP/Contents/Resources/NativeAcceptance/A.json"
    cp "$ROOT/Fixtures/mri-followup.json" "$APP/Contents/Resources/NativeAcceptance/B.json"
fi
plutil -lint "$APP/Contents/Info.plist" "$ROOT/Packaging/SidecarCompare.entitlements"
# Development-only ad-hoc signature. This is neither Developer ID signing nor notarization.
codesign --force --sign - --entitlements "$ROOT/Packaging/SidecarCompare.entitlements" "$APP"
codesign --verify --strict --verbose=2 "$APP"
rm -rf "$ROOT/dist/SidecarCompare.app"
mv "$APP" "$ROOT/dist/SidecarCompare.app"
echo "Built: $ROOT/dist/SidecarCompare.app"
