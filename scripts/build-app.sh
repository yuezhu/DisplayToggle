#!/bin/zsh
# Build "Display Toggle.app" without Xcode: SwiftPM release build → app bundle → ad-hoc signature.
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release --product DisplayToggle
BIN="$(swift build -c release --show-bin-path)/DisplayToggle"

APP="build/Display Toggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DisplayToggle"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"
