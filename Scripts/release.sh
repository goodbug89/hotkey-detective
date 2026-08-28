#!/bin/bash
# 공증된 DMG를 만든다.  사용법: Scripts/release.sh <version>
#
# 사전 준비(한 번만):
#   xcrun notarytool store-credentials "HotkeyDetective" \
#     --key /path/to/AuthKey_XXXXXXXX.p8 --key-id XXXXXXXX --issuer <issuer-uuid>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "사용법: Scripts/release.sh <version>   예: Scripts/release.sh 1.0.0" >&2; exit 1; }
PROFILE="${NOTARY_PROFILE:-HotkeyDetective}"
APP="build/HotkeyDetective.app"
DMG="build/HotkeyDetective-$VERSION.dmg"
STAGE="build/dmg-stage"

# `|| true`가 없으면 인증서가 하나도 없을 때 grep이 1을 반환하고, pipefail+set -e가
# 스크립트를 여기서 죽인다 — ad-hoc 폴백이 정작 필요한 환경에서 도달하지 못한다.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)}"
if [ -z "$IDENTITY" ]; then
  echo "에러: Developer ID Application 인증서가 없습니다. 공증에는 ad-hoc 서명을 쓸 수 없습니다." >&2
  exit 1
fi

echo "==> 테스트"
swift test

echo "==> 빌드 및 서명 ($VERSION)"
CFBundleShortVersionString="$VERSION" Scripts/bundle.sh release
# Info.plist의 버전을 인자와 맞춘다 — 릴리스마다 손으로 고치는 것을 피한다.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
# plist를 고쳤으므로 다시 서명해야 한다(서명은 Info.plist를 포함한다).
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> DMG 생성"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "HotkeyDetective" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> 공증 제출 (수 분 걸릴 수 있음)"
if ! xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait; then
  echo "" >&2
  echo "공증 실패. 자격증명이 없다면 먼저 등록하세요:" >&2
  echo "  xcrun notarytool store-credentials \"$PROFILE\" --key <AuthKey.p8> --key-id <id> --issuer <uuid>" >&2
  exit 1
fi

echo "==> 티켓 스테이플 및 검증"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

rm -rf "$STAGE"
echo ""
echo "완료: $DMG"
