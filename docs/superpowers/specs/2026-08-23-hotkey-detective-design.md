# HotkeyDetective — 설계 스펙

작성일: 2026-08-23
상태: 승인 대기

## 1. 목적

macOS에서 특정 글로벌 단축키 조합(예: ⌘⇧4)을 **누가 점유하고 있는지** 알려주는 메뉴바 유틸리티.
macOS에는 이를 알려주는 공개 API가 없으므로, 여러 간접 신호(증거)를 수집해 판정한다.

사용자가 이 앱을 꺼내는 순간은 항상 "방금 어떤 조합이 안 먹혔을 때"다. 따라서 v1은 **탐침(probe)형**:
조합 하나를 입력받아 그 조합에 대한 판정을 내린다. 전체 단축키 인벤토리는 범위 밖.

## 2. 결정 사항

| 항목 | 결정 |
|---|---|
| 형태 | 메뉴바 전용 (`LSUIElement = YES`), Dock 없음 |
| 배포 | 직접 배포(공증된 DMG). 샌드박스 없음 |
| 최소 OS | macOS 14 (Sonoma) |
| 스택 | Swift 5.10+, SwiftUI `MenuBarExtra`, Swift Package + 얇은 Xcode 앱 타깃 |
| 엔진 구조 | 증거 파이프라인: `Resolver` 여러 개 → `Evidence` → `VerdictBuilder` → `Verdict` |
| 권한 | 손쉬운 사용(Accessibility). 없으면 제한 모드(파일 기반 Resolver만) |

## 3. 모듈 구조

```
HotkeyDetective/
├── App/                      # 실행 타깃
│   ├── HotkeyDetectiveApp.swift
│   ├── ProbeSession.swift     # ObservableObject, 상태 머신, UI↔엔진 연결
│   └── Views/
│       ├── PermissionView.swift
│       ├── ProbeView.swift    # idle / listening
│       └── VerdictView.swift
├── Engine/                   # 순수 로직. AppKit/CG 직접 호출 금지 (CarbonOccupancy는 프로토콜 뒤로)
│   ├── KeyCombo.swift
│   ├── Evidence.swift         # Evidence, Confidence, Owner, Verdict
│   ├── Resolver.swift         # protocol Resolver, ProbeSnapshot, SystemState
│   ├── VerdictBuilder.swift
│   └── Resolvers/
│       ├── SystemHotkeyResolver.swift
│       ├── CarbonOccupancyResolver.swift   # HotKeyRegistrar 프로토콜 주입
│       ├── ReactionResolver.swift
│       └── KnownApps/
│           ├── KnownAppResolver.swift      # 공통 베이스: 파일 로드, 실행 중 확인, 신뢰도
│           ├── RaycastResolver.swift
│           ├── RectangleResolver.swift
│           ├── AlfredResolver.swift
│           ├── MaccyResolver.swift
│           └── OnePasswordResolver.swift
└── Probe/                    # OS 밀착 계층
    ├── EventTapListener.swift
    ├── SystemSnapshot.swift
    ├── CarbonHotKeyRegistrar.swift         # HotKeyRegistrar 실제 구현
    └── AccessibilityGate.swift
```

**의존 방향:** App → Engine, App → Probe. Engine은 Probe를 모른다. Probe는 Engine의 타입(`KeyCombo`, `SystemState`)만 생성한다.

## 4. 데이터 흐름

1. 사용자가 "탐침 시작" 클릭 → `ProbeSession.state = .listening`
2. `EventTapListener.start()` — 탭 생성, `SystemSnapshot.capture()` → `before`
3. 유효 keyDown 수신(수정자 1개 이상 포함) → `combo` 확정 → 탭 중지
4. `REACTION_DELAY`(기본 300ms) 대기 → `SystemSnapshot.capture()` → `after`
5. `ProbeSnapshot(before, after, elapsed)` 구성
6. 모든 `Resolver.resolve(combo, probe:)` 호출(각각 독립, 실패는 빈 배열) → `[Evidence]`
7. `VerdictBuilder.build(evidence)` → `Verdict`
8. `state = .result(combo, verdict)`

## 5. 핵심 타입

```swift
struct KeyCombo: Hashable, Codable {
    let keyCode: UInt16            // CGKeyCode, 레이아웃 독립
    let modifiers: Modifiers       // OptionSet: command, shift, option, control, function
    var display: String { get }    // 현재 레이아웃 기준 "⌘⇧4"
}

enum Confidence: Int, Comparable { case low, medium, high, certain }

enum Owner: Hashable {
    case system(feature: String)                           // "영역 스크린샷"
    case app(bundleID: String, name: String, action: String?)
}

struct Evidence {
    let source: String       // Resolver 이름 (사용자 표시용)
    let owner: Owner?        // nil = 점유됐으나 소유자 미상
    let confidence: Confidence
    let rationale: String    // 한 문장 근거
}

enum Verdict {
    case confirmed(Owner, [Evidence])
    case likely(Owner, [Evidence])
    case contested([Owner], [Evidence])
    case occupiedUnknown([Evidence])
    case free([Evidence])
}

struct SystemState {
    let windows: [pid_t: Set<CGWindowID>]   // on-screen 창
    let frontmostPID: pid_t?
}

struct ProbeSnapshot {
    let before: SystemState
    let after: SystemState
    let elapsed: TimeInterval
}

protocol Resolver {
    var name: String { get }
    func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence]   // probe nil = 제한 모드
}

protocol HotKeyRegistrar {
    func tryRegister(_ combo: KeyCombo) -> RegistrationResult   // .registeredAndReleased / .occupied / .error(OSStatus)
}
```

## 6. Resolver 명세

### 6.1 SystemHotkeyResolver
- 소스: `~/Library/Preferences/com.apple.symbolichotkeys.plist` → `AppleSymbolicHotKeys` 딕셔너리.
- 항목 ID → 기능명 매핑 테이블 내장(스크린샷 28~31, Spotlight 64/65, 입력소스 60/61, Mission Control 32~ 등). 미지 ID는 "시스템 기능 #N".
- `enabled == true`이고 `value.parameters`의 (keyCode, modifiers)가 일치 → `Evidence(owner: .system, confidence: .certain)`.
- plist에 없는 기본값 항목도 있으므로, 기본 단축키 테이블을 내장하고 plist에 명시적 비활성이 없으면 기본값 적용.
- `probe` 불필요 (제한 모드에서도 동작).

### 6.2 CarbonOccupancyResolver
> **[실측 한계 2026-08-23]** `eventHotKeyExistsErr(-9878)`는 같은 프로세스 내 중복 등록에서만 발생한다. Rectangle(Carbon 핫키 사용)이 잡은 ⌃⌥→에도 `registeredAndReleased`가 반환됨. 따라서 이 Resolver는 실전에서 증거를 내지 못하며, "점유 여부 100%"라는 설계 가정은 틀렸다. 해롭지 않아 유지하되 신호로 기대하지 않는다. 대안(CGSGetGlobalHotKeys 등 비공개 API)은 v2 검토.

- `HotKeyRegistrar.tryRegister(combo)` 호출. `.occupied`(`eventHotKeyExistsErr`, -9878) → `Evidence(owner: nil, confidence: .high, rationale: "다른 프로세스가 Carbon 핫키로 등록함")`.
- 성공 시 즉시 해제, 증거 없음. `.error`는 로그만.
- `probe` 불필요.

### 6.3 ReactionResolver
- `probe` 필수. nil이면 빈 배열.
- `after.windows − before.windows` 에서 새 창을 가진 pid 집합 + `frontmostPID` 변경 여부.
- 제외 목록: 자기 자신, `WindowServer`, `Dock`, `SystemUIServer`, `ControlCenter`, `NotificationCenter`, `loginwindow`.
- 반응 pid 1개 → `.high`, 2개 이상 → 각각 `.medium`. pid는 `NSRunningApplication(processIdentifier:)`로 bundleID/이름 변환 (이 변환은 Probe 계층이 `SystemState`에 미리 넣어 전달: `[pid_t: AppIdentity]`).

### 6.4 KnownAppResolver (베이스) + 앱별 구현
- 공통: 설정 파일 경로(들) → 로드 → 앱별 파서로 `[(action, KeyCombo)]` 추출 → 일치 항목마다 Evidence.
- 신뢰도: 앱 실행 중 → `.high`, 미실행 → `.low` (rationale에 "현재 실행 중 아님 — 실행 시 충돌 예상" 명시).
- 파일 없음/파싱 실패 → 빈 배열 + `os_log(.debug)`.
- v1 대상과 **조사 필요 사항**: 아래 경로·키 이름은 구현 시 실제 파일로 검증하고, 각 앱의 실제 plist를 테스트 픽스처로 저장한다.

| 앱 | 예상 경로 | 메모 |
|---|---|---|
| Raycast | `~/Library/Preferences/com.raycast.macos.plist` | 글로벌 호출키 + 익스텐션 핫키 |
| Rectangle | `~/Library/Preferences/com.knollsoft.Rectangle.plist` | 액션별 `{keyCode, modifierFlags}` |
| Alfred | `~/Library/Application Support/Alfred/Alfred.alfredpreferences/preferences/local/<host>/` | plist 트리 |
| Maccy | `~/Library/Preferences/org.p0deje.Maccy.plist` | KeyboardShortcuts 라이브러리 직렬화 |
| 1Password | `~/Library/Group Containers/2BUA8C4S2C.com.1password/` | 위치·포맷 조사 필요. 확인 안 되면 v1에서 제외 |

## 7. VerdictBuilder 규칙 (순서대로 첫 매칭)

1. `certain` 증거의 owner 집합이 1개 → `confirmed`. 2개 이상 → `contested`.
2. `certain` 없음. `high` 이상 증거의 non-nil owner 집합이 정확히 1개 → `likely`.
3. non-nil owner 후보가 2개 이상 → `contested` (최고 신뢰도순 정렬).
4. owner가 전부 nil이지만 증거 존재 → `occupiedUnknown`.
5. 증거 없음 → `free`.

`low`만 있는 경우(미실행 앱 설정만 일치)는 `free`로 판정하되 증거 목록에 남겨 "실행하면 충돌" 경고로 표시.

## 8. Probe 계층

### EventTapListener
- `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: keyDown)`.
- **listenOnly**: 이벤트를 소비하지 않는다. 실제 소유자가 정상 반응해야 ReactionResolver가 관찰할 수 있다.
- 수정자 없는 키는 무시하고 계속 대기. `Esc`는 취소.
- `tapDisabledByTimeout` / `tapDisabledByUserInput` 콜백 시 재활성화.
- 15초 무입력 → 타임아웃, 탭 해제, `idle` 복귀.
- 탭 생성 실패 → `needsPermission`.

### SystemSnapshot
- `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` → pid별 windowID 집합.
- `NSWorkspace.shared.frontmostApplication`.
- `NSWorkspace.shared.runningApplications`로 `[pid: AppIdentity(bundleID, name)]` 구성.

### CarbonHotKeyRegistrar
- `RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)` → `noErr`면 즉시 `UnregisterEventHotKey(ref)`. `-9878` → `.occupied`.

### AccessibilityGate
- `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`.
- 미승인 시 1초 폴링, 승인되면 `idle`로 전환.
- 설정 딥링크: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

## 9. UI

### 상태
```swift
enum ProbeState {
    case needsPermission
    case idle
    case listening
    case resolving(KeyCombo)
    case result(KeyCombo, Verdict)
}
```

### 팝오버 (너비 360pt)
- **needsPermission**: 한 문장 설명 + "시스템 설정 열기" + "권한 없이 제한 모드 사용" 링크.
- **idle**: "탐침 시작" 주 버튼. 하단 작은 링크 "조합을 직접 지정" → 수정자 체크박스 + 키 팝업(제한 모드 입력, `probe: nil`로 Resolver 실행).
- **listening**: "지금 조합을 눌러보세요" + 펄스 애니메이션 + "Esc로 취소".
- **result** (위→아래):
  1. 조합 글리프 크게 (`⌘⇧4`)
  2. 판정 한 줄 (색: confirmed/likely 파랑, contested 주황, occupiedUnknown 회색, free 초록)
     - confirmed: "**{owner}**이(가) 사용 중"
     - likely: "**{owner}**이(가) 사용 중인 것으로 보임"
     - contested: "**A**와 **B**가 모두 등록함"
     - occupiedUnknown: "어떤 앱이 점유 중이지만 누구인지 찾지 못함"
     - free: "아무도 사용하지 않음"
  3. 근거 목록 (DisclosureGroup, 기본 펼침): `source · rationale · 신뢰도 점 4개`
  4. 액션: 시스템 owner → "키보드 단축키 설정 열기"; 앱 owner → "{앱} 열기"(activate만); 공통 → "다시 탐침", "결과 복사"
  5. occupiedUnknown 전용 안내: "아직 모르는 앱일 수 있어요. 짐작 가는 앱을 종료하고 다시 시도해보세요."
- 팝오버 밖 클릭 시 닫힘, 상태 유지.
- 메뉴바 아이콘: SF Symbol `keyboard.badge.ellipsis`. 우클릭 메뉴: "로그인 시 실행" 토글(`SMAppService`), "종료".

## 10. 에러 처리

| 상황 | 처리 |
|---|---|
| 이벤트 탭 생성 실패 | `needsPermission` |
| 탐침 15초 무입력 | 탭 해제, `idle` |
| Resolver 예외/파일 오류 | 해당 Resolver 빈 배열, `os_log(.debug)`. 다른 Resolver 계속 |
| plist 포맷 불일치 | 동일 |
| Carbon 등록 `.error` | 증거 없음, 로그 |

## 11. 테스트

Engine 모듈 XCTest. 실제 권한 불필요.

- `KeyComboTests`: 글리프 표기, Carbon 수정자 비트/`CGEventFlags`/plist 정수 ↔ `Modifiers` 왕복.
- `SystemHotkeyResolverTests`: 픽스처 3종(기본, 일부 비활성, 커스텀 변경) + 기본값 폴백.
- `CarbonOccupancyResolverTests`: 가짜 `HotKeyRegistrar`로 성공/점유/에러.
- `ReactionResolverTests`: 새 창 1개 / frontmost 변경 / 반응 없음 / 자기 자신만 반응 / 2개 앱 반응.
- `VerdictBuilderTests`: 규칙 5개 각각 + contested + low만 있는 케이스.
- `KnownApps/*Tests`: 앱별 실제 plist 픽스처 ≥1, 깨진 파일, 미실행 → low.

**수동 검증 체크리스트:**
- ⌘⇧4 → confirmed(시스템 영역 스크린샷)
- Raycast 호출키 → likely/confirmed(Raycast)
- Rectangle 키 → likely(Rectangle)
- ⌃⌥⌘F12 → free
- CleanShot 등이 ⌘⇧4를 가로채는 환경 → contested
- 권한 미승인 상태 → PermissionView → 승인 후 자동 전환
- 제한 모드에서 ⌘⇧4 지정 → SystemHotkey만으로 confirmed

## 12. v1 범위 밖

글로벌 소환 단축키, 단축키 인벤토리 뷰, 탐침 이력, Sparkle 자동 업데이트, Mac App Store, 다국어(UI 한국어 단일).

## 13. 미해결/검증 항목 (구현 시 확인)

- 각 KnownApp의 실제 설정 경로와 키 이름.
- `REACTION_DELAY` 300ms가 Raycast/Alfred 창 표시에 충분한지 실측.
  - **[검증됨 2026-08-23]** Rectangle 0.99 설치 후 ⌃⌥→ → `likely(Rectangle · rightHalf)` (기본 테이블 경로). Rectangle은 기본 단축키를 plist에 쓰지 않음 → 파서에 Recommended/Spectacle 기본 테이블 추가.
  - **[검증됨 2026-08-23]** ⌘Space → `confirmed(Spotlight 검색)`, 근거 2건: 시스템 단축키 64 + 반응 감지 "334ms 후 Spotlight 새 창 1개". 300ms 유지. ⌃⌥⌘F12 → `free`, 근거 0건 (fn 비트 제거 동작 확인). Rectangle/Maccy/Raycast·contested 케이스는 해당 앱 미설치로 미검증.
- `.cgSessionEventTap`에서 Carbon 핫키로 소비되는 이벤트가 listenOnly 탭에 도달하는지 확인 (예상: 도달함). 아니면 `.cgHIDEventTap`으로 전환.
  - **[검증됨 2026-08-23, 번들 앱 + 손쉬운 사용/입력 모니터링 허용]** ⇧⌘4 입력이 `.cgSessionEventTap` listenOnly 탭에 도달, 판정 `confirmed(system("영역 스크린샷"))`, 근거 1건(시스템 단축키 항목 30). 반응 감지·Carbon 점유 증거 없음은 예상대로.
- `symbolichotkeys` ID ↔ 기능명 매핑 테이블의 완전성.
- **[Task 7 Step 5 실측, 2026-08-23]** `CarbonHotKeyRegistrar.tryRegister` 실기 검증(임시 `main.swift`, macOS 관리자 계정, Screenshot 단축키 ⌘⇧4 관찰 당시 비어있지 않은 기본 상태): `⌘⇧4` → `registeredAndReleased`, `⌃⌥⌘F12` → `registeredAndReleased`. 두 호출 모두 `registeredAndReleased`로 관찰됨 — 브리프에 명시된 대로 시스템 단축키(⌘⇧4)가 Carbon 핫키 테이블을 거치지 않을 수 있다는 것과 일치하는 유효한 관찰이며 "고치지" 않음. 둘째 줄(임의 미사용 조합)은 기대대로 `registeredAndReleased`.
- **[Task 8 Step 2 실측, 2026-08-23]** `미검증: 권한 없음`. `EventTapListener` 실기 검증(임시 `main.swift`, `swift build && .build/debug/HotkeyDetective`, 이 세션의 셸/터미널 프로세스): `trusted: false` (`AccessibilityGate.isTrusted(prompt: true)`), 곧이어 `tapFailed` — `CGEvent.tapCreate`가 손쉬운 사용 권한 없이 nil을 반환해 `EventTapListener.start` 가드가 즉시 `.tapFailed`로 종료됨(15초 타임아웃까지 대기하지 않고 즉시 종료 — 코드 경로가 의도대로 동작함을 확인). 브리프 지시대로 권한을 얻기 위한 루프나 시스템 설정 변경은 시도하지 않음. 따라서 ⌘⇧4 `confirmed(system(...))` 관찰, ⌃⌥⌘F12 `free` 관찰, `REACTION_DELAY` 300ms 충분성 실측, `.cgSessionEventTap` vs `.cgHIDEventTap` 도달성 확인은 모두 이 세션에서 수행 불가 — 미해결로 남김. 이 결과를 얻은 프로세스에 손쉬운 사용 권한을 부여한 뒤(시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용) 사람이 직접 재실행해 확인 필요.
