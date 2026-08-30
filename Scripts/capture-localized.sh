#!/bin/bash
# 판정 화면을 언어별로 렌더링해 PNG로 남긴다.  사용법: Scripts/capture-localized.sh [출력디렉터리]
#
# 번역이 화면에서 잘리는지, RTL 언어에서 배치가 뒤집히는지는 문자열 검사로 알 수 없다.
# 실제로 독일어·러시아어 등 7개 언어에서 버튼이 "Ergebnis kopi..."로 잘리고 있었고,
# 카탈로그는 그때도 완전무결했다 — 키도 다 있고 포맷 지정자도 맞았다. 그려봐야 보인다.
#
# 여기서 나온 영어 화면이 docs/images/의 원본이다 — 사이트와 15개 README가 참조한다.
# 교체는 릴리스 게시 직전에 한다(Scripts/release.sh가 정확한 명령을 출력한다).
# 미리 갈아끼우면 아직 배포되지 않은 화면을 광고하게 된다.
#
# CaptureMode는 DEBUG_CAPTURE 플래그가 있을 때만 컴파일된다 — 배포 빌드에는 없다.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/shots}"
LANGS=(en ko ja zh-Hans zh-Hant de fr es it pt-BR ru ar th tr vi)

swift build -c release -Xswiftc -DDEBUG_CAPTURE
APP="build/Capture.app"
rm -rf "$APP" "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT"
cp .build/release/HotkeyDetective "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp -R Sources/HotkeyDetective/Resources/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

for L in "${LANGS[@]}"; do
  # -AppleLanguages는 인자 도메인으로 들어가 CFBundle 협상을 그대로 태운다.
  # 시스템 언어를 바꾸지 않고도 그 언어의 실제 화면을 볼 수 있다.
  "$APP/Contents/MacOS/HotkeyDetective" --capture "$OUT" -AppleLanguages "($L)"
done
rm -rf "$APP"
echo "완료: $OUT ($(ls "$OUT" | wc -l | tr -d ' ')개)"
