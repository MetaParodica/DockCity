#!/usr/bin/env bash
# Wrap a built Dockman executable into a faceless agent .app bundle (LSUIElement)
# and ad-hoc sign it so it runs as an agent on this machine.
#
# Usage: ./scripts/make-app.sh [target] [config]
#   target: app   (default) -> dockman        -> Dockman.app
#           spike           -> dockman-spike  -> Dockman-Spike.app
#   config: release (default) | debug
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { echo "Dock City packaging requires macOS 14+ and Xcode." >&2; exit 1; }

TARGET="${1:-app}"
CONFIG="${2:-release}"

case "$TARGET" in
  app)   EXEC="dock-city";     APP_NAME="Dock City";     BUNDLE_ID="com.metaparodica.DockCity"; DISPLAY="Dock City" ;;
  spike) EXEC="dockman-spike"; APP_NAME="DockCity-Spike"; BUNDLE_ID="com.metaparodica.DockCity.spike"; DISPLAY="Dock City (Spike)" ;;
  *) echo "target must be 'app' or 'spike'"; exit 1 ;;
esac

case "$CONFIG" in
  debug)   BUILD_FLAGS="" ;;
  release) BUILD_FLAGS="-c release" ;;
  *) echo "config must be 'debug' or 'release'"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/${APP_NAME}.app"

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
      <key>CFBundleURLSchemes</key>  <array><string>dockcity</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

echo "▶ Ad-hoc signing (local run only)…"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "✅ Built $APP"
echo "   Run:  open \"$APP\""
echo "   Quit: killall ${EXEC}    (or use the menu-bar item ▸ Quit)"
