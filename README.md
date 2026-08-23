# HotkeyDetective

"이 단축키 누가 먹었지?" — macOS 글로벌 단축키 점유자를 찾는 메뉴바 유틸리티.

## 빌드
    swift test
    Scripts/bundle.sh          # build/HotkeyDetective.app
    open build/HotkeyDetective.app

## 권한
**손쉬운 사용(Accessibility)** 과 **입력 모니터링(Input Monitoring)** 권한이 모두 필요합니다.
macOS는 이벤트 탭 생성에 두 권한을 함께 요구하므로, 시스템 설정 > 개인정보 보호 및 보안의
두 목록 모두에서 HotkeyDetective를 켜야 합니다. 키 입력은 관찰만 하며 가로채거나 저장하지 않습니다.

> **서명과 권한 유지.** `Scripts/bundle.sh`는 키체인에 Developer ID Application 인증서가 있으면 그것으로,
> 없으면 `CODESIGN_IDENTITY` 환경변수의 인증서로, 둘 다 없으면 ad-hoc으로 서명합니다.
> 고정 인증서로 서명하면 재빌드해도 권한이 유지됩니다. ad-hoc 서명은 빌드마다 다른 앱으로 취급되어
> 두 목록에서 기존 항목을 (`-`) 지우고 새 번들을 다시 추가해야 합니다. 서명 방식을 바꾼 직후에도 한 번은 재추가가 필요합니다.

권한 없이도 **제한 모드**로 쓸 수 있습니다. 이 경우 키 입력 감지와 반응 감지 없이,
수동으로 고른 조합에 대해 설정 파일 기반 증거만 조회합니다.

## 판정 원리
시스템 단축키 plist · Carbon 핫키 등록 시도 · 입력 직후 창/활성 앱 변화 · 알려진 앱 설정 파일 —
네 가지 증거를 합쳐 판정합니다.

지원하는 알려진 앱:

| 앱 | 상태 |
| --- | --- |
| Rectangle | 지원 |
| Maccy | 지원 |
| Raycast | **실험적** — 설정 포맷을 실기기에서 검증하지 못했습니다(스펙 13절). 조회되지 않을 수 있습니다. |

Alfred와 1Password는 v1 범위에 포함되지 않습니다.
