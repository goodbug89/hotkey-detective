#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONF="${1:-release}"
swift build -c "$CONF"
APP="build/HotkeyDetective.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONF/HotkeyDetective" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"      # ad-hoc. 배포 시 Developer ID로 교체
echo "built $APP"
