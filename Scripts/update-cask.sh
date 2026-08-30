#!/bin/bash
# 릴리스 게시 후 Homebrew 탭의 cask를 갱신한다.  사용법: Scripts/update-cask.sh <version>
#
# 순서가 중요하다: GitHub 릴리스에 DMG가 올라간 뒤에 실행해야 한다. cask의 sha256은
# 사용자가 내려받을 바로 그 파일의 해시여야 하므로, 로컬 빌드가 아니라 게시된 자산을
# 받아서 계산한다 — 둘이 다르면 brew가 설치를 거부하고 그 사실은 사용자 쪽에서만 드러난다.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "사용법: Scripts/update-cask.sh <version>" >&2; exit 1; }
TAP_REPO="${TAP_REPO:-goodbug89/homebrew-tap}"
URL="https://github.com/goodbug89/hotkey-detective/releases/download/v$VERSION/HotkeyDetective-$VERSION.dmg"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 게시된 자산 확인"
if ! curl -fsSL -o "$TMP/app.dmg" "$URL"; then
  echo "에러: $URL 을 받을 수 없습니다. 릴리스를 먼저 게시하세요." >&2
  exit 1
fi
SHA="$(shasum -a 256 "$TMP/app.dmg" | cut -d' ' -f1)"
echo "    sha256 = $SHA"

echo "==> 탭 갱신"
git clone -q "https://github.com/$TAP_REPO.git" "$TMP/tap"
CASK="$TMP/tap/Casks/hotkey-detective.rb"
/usr/bin/sed -i '' -e "s|^  version \".*\"|  version \"$VERSION\"|" \
                   -e "s|^  sha256 \".*\"|  sha256 \"$SHA\"|" "$CASK"

if git -C "$TMP/tap" diff --quiet; then
  echo "    변경 없음 — 이미 $VERSION 입니다."
  exit 0
fi
git -C "$TMP/tap" commit -qam "hotkey-detective $VERSION"
git -C "$TMP/tap" push -q origin HEAD
echo "완료: $TAP_REPO 가 $VERSION 을 가리킵니다."
