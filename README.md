# HotkeyDetective

"이 단축키 누가 먹었지?" — macOS 글로벌 단축키 점유자를 찾는 메뉴바 유틸리티.

## 빌드
    swift test
    Scripts/bundle.sh          # build/HotkeyDetective.app
    open build/HotkeyDetective.app

## 권한
손쉬운 사용(Accessibility) 권한이 필요합니다. 키 입력은 관찰만 하며 가로채거나 저장하지 않습니다.

## 판정 원리
시스템 단축키 plist · Carbon 핫키 등록 시도 · 입력 직후 창/활성 앱 변화 · 알려진 앱(Rectangle, Maccy, Raycast) 설정 파일 — 네 가지 증거를 합쳐 판정합니다.
