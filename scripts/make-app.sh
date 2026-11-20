#!/usr/bin/env bash
# Wrap the Dock tracking agent into an .app bundle (LSUIElement)
# and sign it (ad-hoc unless DOCKCITY_SIGN_IDENTITY selects a local identity).
#
# Usage: ./scripts/make-app.sh [target] [config]
#   target: app   (default) -> dock-city -> Dock City.app
#           probe           -> dock-city-overlay-probe -> Dock City Overlay Probe.app
#   config: release (default) | debug
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { echo "Dock City packaging requires macOS 14+ and Xcode." >&2; exit 1; }

TARGET="${1:-app}"
CONFIG="${2:-release}"

case "$TARGET" in
  app)   EXEC="dock-city";     APP_NAME="Dock City";     BUNDLE_ID="com.metaparodica.DockCity"; DISPLAY="Dock City" ;;
  probe) EXEC="dock-city-overlay-probe"; APP_NAME="Dock City Overlay Probe"; BUNDLE_ID="com.metaparodica.DockCity.overlayProbe"; DISPLAY="Dock City Overlay Probe" ;;
  *) echo "target must be 'app' or 'probe'"; exit 1 ;;
esac

case "$CONFIG" in
  debug)   BUILD_FLAGS="" ;;
  release) BUILD_FLAGS="-c release" ;;
  *) echo "config must be 'debug' or 'release'"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/${APP_NAME}.app"
URL_SCHEME="dockcity"
if [[ "$TARGET" == probe ]]; then URL_SCHEME="dockcity-overlay-probe"; fi

echo "▶ Building $EXEC ($CONFIG)…"
swift build $BUILD_FLAGS --product "$EXEC"

BIN_PATH="$(swift build $BUILD_FLAGS --show-bin-path)/${EXEC}"
[ -x "$BIN_PATH" ] || { echo "binary not found at $BIN_PATH"; exit 1; }

echo "▶ Assembling $APP …"
if [[ -e "$APP" ]]; then
  mv "$APP" "$(mktemp -d build/previous-app.XXXXXX)/${APP_NAME}.app"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/${EXEC}"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>     <string>${DISPLAY}</string>
  <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key>      <string>${EXEC}</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleShortVersionString</key> <string>0.1.0</string>
  <key>CFBundleVersion</key>         <string>1</string>
  <key>LSMinimumSystemVersion</key>  <string>14.0</string>
  <!-- Faceless agent: no system-Dock icon, no app menu. -->
  <key>LSUIElement</key>             <true/>
  <key>NSHighResolutionCapable</key> <true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>     <string>${BUNDLE_ID}</string>
      <key>CFBundleURLSchemes</key>  <array><string>${URL_SCHEME}</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

SIGN_IDENTITY="${DOCKCITY_SIGN_IDENTITY:--}"
echo "▶ Signing (DOCKCITY_SIGN_IDENTITY, default: ad-hoc)…"
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign -dr - "$APP"

echo "✅ Built $APP"
echo "   Run:  open \"$APP\""
echo "   Quit: killall ${EXEC}    (or use the menu-bar item ▸ Quit)"
