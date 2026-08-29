#!/bin/bash
# 빌드된 .app이 실제로 지역화된 상태인지 검사한다.
#
# 이 검사가 없어서 v1.0.0/v1.0.1이 두 가지로 깨진 채 배포됐다:
#  1) 언어 카탈로그가 .app에 하나도 복사되지 않아 macOS가 앱을 영어 전용으로 판정
#  2) Bundle.module이 빌드 머신의 .build 절대경로로 폴백 — 다른 맥에서는 실행 즉시 크래시
# 둘 다 단위 테스트로는 보이지 않는다. 포장 단계에서만 관측되므로 여기서 막는다.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-build/HotkeyDetective.app}"
SRC="Sources/HotkeyDetective/Resources"
fail=0

for dir in "$SRC"/*.lproj; do
  lang="$(basename "$dir")"
  target="$APP/Contents/Resources/$lang/Localizable.strings"
  if [ ! -f "$target" ]; then
    echo "누락: $lang/Localizable.strings 가 .app에 없다"; fail=1; continue
  fi
  if ! plutil -lint "$target" >/dev/null 2>&1; then
    echo "파싱 실패: $target — strings 문법 오류면 그 언어 전체가 조용히 영어로 떨어진다"; fail=1
  fi
done

# 카탈로그가 Contents/Resources에 있어야 CFBundle이 메인 번들을 다국어로 인식한다.
# .app 루트에 얹는 배치는 코드서명이 봉인하지 못하므로 여기서 명시적으로 거부한다.
if [ -e "$APP/HotkeyDetective_HotkeyDetective.bundle" ]; then
  echo "잘못된 배치: 리소스 번들이 .app 루트에 있다 — 코드서명이 봉인하지 못한다"; fail=1
fi

[ "$fail" -eq 0 ] || { echo "verify-app: 실패"; exit 1; }
echo "verify-app: $(ls -d "$SRC"/*.lproj | wc -l | tr -d ' ')개 언어 카탈로그 확인"
