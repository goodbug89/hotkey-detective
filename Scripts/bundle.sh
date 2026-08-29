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
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# 서명: CODESIGN_IDENTITY 환경변수 > Developer ID Application > ad-hoc.
# 고정된 인증서로 서명해야 재빌드 후에도 손쉬운 사용/입력 모니터링 권한이 유지된다.
# `|| true`가 없으면 인증서가 하나도 없을 때 grep이 1을 반환하고, pipefail+set -e가
# 스크립트를 여기서 죽인다 — ad-hoc 폴백이 정작 필요한 환경에서 도달하지 못한다.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)}"
if [ -n "$IDENTITY" ]; then
  # 보안 타임스탬프는 공증의 필수 조건이다 — --timestamp=none이면 공증이 거부된다.
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  echo "signed with: $IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "signed ad-hoc (no Developer ID found) — 재빌드마다 권한 재허용 필요"
fi
echo "built $APP"
