#!/usr/bin/env bash
#
# Assemble canyon-editor/build/Canyon Editor.app.
#
# SwiftPM only produces a bare executable, and a bare executable can't be a
# proper macOS app -- no Info.plist means no menu bar, no dock icon, and
# UserDefaults with nowhere to live. So: build, then wrap.
#
# Xcode isn't required; the Command Line Tools SDK carries SwiftUI.

set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/Canyon Editor.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/CanyonEditor"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/CanyonEditor"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Canyon Editor</string>
    <key>CFBundleDisplayName</key>     <string>Canyon Editor</string>
    <key>CFBundleExecutable</key>      <string>CanyonEditor</string>
    <key>CFBundleIdentifier</key>      <string>org.jacobian.canyon-editor</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: unsigned bundles get a fresh identity on every rebuild,
# which loses the remembered database path.
codesign --force --sign - "$APP"

echo "built $PWD/$APP"
