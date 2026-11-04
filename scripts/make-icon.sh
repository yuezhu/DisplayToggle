#!/bin/zsh
# Regenerate Resources/AppIcon.icns from scripts/make-icon.swift.
set -euo pipefail
cd "${0:A:h}/.."
ICONSET=.build/AppIcon.iconset
rm -rf "$ICONSET"
swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Wrote $PWD/Resources/AppIcon.icns"
