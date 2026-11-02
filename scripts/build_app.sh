#!/usr/bin/env bash
# Builds dist/CatCompanionOverlay.app (release, ad-hoc signed).
# Usage: scripts/build_app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="CatCompanionOverlay"
BUNDLE_ID="com.kent.catcompanionoverlay"
VERSION="0.1.0"
APP="dist/${NAME}.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/${NAME}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${NAME}"
cp -R "Sources/${NAME}/sprites" "$APP/Contents/Resources/sprites"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${NAME}</string>
  <key>CFBundleDisplayName</key><string>Cat Companion Overlay</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Ad-hoc sign with a fixed identifier so macOS treats it as a distinct app.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
codesign --verify --verbose "$APP"
echo "Built $APP"
