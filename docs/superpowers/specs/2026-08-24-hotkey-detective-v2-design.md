# HotkeyDetective v2 — 설계 스펙

작성일: 2026-08-24
상태: 승인 대기
선행: v1 (`2026-08-23-hotkey-detective-design.md`) — Engine/Probe/App 3계층, 실기 검증 완료

## 1. 목적

v1의 실제 맹점 두 가지를 해소한다.
1. **미지 앱 탐지(A):** 창을 띄우지 않고 plist에도 파서가 없는 앱이 조합을 점유하면 v1은 `free`로 오답. 범용 plist 스캐너로 커버리지를 넓힌다.
2. **인벤토리(B):** "이 조합 하나"가 아니라 "등록된 전체 단축키와 충돌"을 훑어보는 별도 창을 추가한다.

동시에 인벤토리 창과 탐침 팝오버를 공통 비주얼 언어로 리디자인한다.

## 2. 스파이크 결과 (2026-08-24, 채택 근거)

- **SkyLight private API 기각:** `SLSGetHotKey` 등 심볼은 존재하나 서드파티 핫키를 **열거**하는 원시함수가 없고, 추측 시그니처가 세그폴트(exit 139)를 냈다. `SLSGetSymbolicHotKey*`는 시스템 심볼릭 핫키만 다뤄 이미 plist로 커버하는 범위. OS 버전 취약성·크래시 위험으로 채택 불가.
- **범용 plist 스캔 채택:** 실행 중 앱(백그라운드 에이전트 포함) 85개를 스캔해, 앱별 파서 없이 두 범용 패턴만으로 Rectangle·Maccy의 핫키를 정확히 추출. 이것이 A의 구현 경로.
- **한계(정직히 명시):** 표준 패턴으로 저장하지 않는 앱(자체 포맷, Karabiner 등), 그리고 plist에 기본값을 안 쓰는 앱(Rectangle은 스캔 시 사용자 지정분만 잡힘 → 정밀 파서로 보완)은 여전히 못 잡는다. Carbon 크로스 프로세스 한계(v1 6.2절)는 그대로.

## 3. 결정 사항

| 항목 | 결정 |
|---|---|
| A 구현 | 범용 `HeuristicScanResolver` (SkyLight 아님) |
| 소스 병합 | **bundleID 단위 배타 배정** — 정밀 파서 담당 앱은 스캐너에서 제외 |
| 인벤토리 배치 | **별도 창** (팝오버 아님) |
| 소스 뱃지 | 사용자에게 노출 (시스템 / 파서 / 스캔) |
| 팝오버 | 인벤토리와 같은 비주얼 언어로 리디자인 |
| 스캔 대상 | 실행 중 앱 + 백그라운드 에이전트, 샌드박스 컨테이너 경로 포함 |

## 4. 스캐너 (A) — HeuristicScanResolver

### 위치
`Sources/Engine/Resolvers/HeuristicScanResolver.swift` (Engine, Foundation만). 실행 중 앱 목록·plist 경로는 Probe가 주입하므로 Engine은 순수 유지.

### 입력
```swift
public struct ScannableApp: Hashable {
    public let bundleID: String
    public let name: String
    public let plistURLs: [URL]   // 일반 + 컨테이너 경로 (Probe가 채움)
}
```
Probe의 `RunningAppsProvider`가 `NSWorkspace.runningApplications`(백그라운드 포함)를 순회해 `[ScannableApp]` 생성. 각 앱의 후보 경로는 v1 `KnownApps.containerPrefs`/`prefs` 규칙 재사용.

### 패턴 (2개, 스파이크 실측)
1. **KeyboardShortcuts 라이브러리:** 키가 `KeyboardShortcuts_`로 시작하고 값이 JSON 문자열 `{"carbonKeyCode":N,"carbonModifiers":M}` → `Modifiers(carbon:)`. (Maccy, Ice, CleanShot 등)
2. **MASShortcut/Cocoa:** 딕셔너리 값에 `keyCode`(정수) + `modifierFlags` 또는 `modifierMask`(CG 비트) → `Modifiers(cgFlags:)`. (Rectangle, 다수 유틸)

plist 전체를 재귀 순회하며 두 패턴을 찾는다. 액션명 = KeyboardShortcuts는 접두어 제거한 키, MAS는 딕셔너리 키.

### 배타 규칙
```swift
public struct HeuristicScanResolver: Resolver {
    let apps: [ScannableApp]
    let excludedBundleIDs: Set<String>   // 정밀 파서 담당 앱 (KnownApps.parserBundleIDs)
}
```
`excludedBundleIDs`에 든 앱은 스캔하지 않는다. `KnownApps`에 `parserBundleIDs: Set<String>` 정적 프로퍼티 추가(rectangle/maccy/raycast의 bundleID).

### 증거
매칭 시 `Evidence(source: "설정 스캔", owner: .app(bundleID:, name:, action:), confidence: .medium, rationale: "\(name) 설정에서 '\(action)' = \(combo.display) 패턴 발견")`. `medium`인 이유: 패턴 추론이라 정밀 파서(`high`)보다 약하고, VerdictBuilder 규칙상 단독이면 `likely`, certain과 충돌 시엔 규칙 1의 high 기준 미달로 `contested`를 일으키지 않는다(약한 신호는 시스템 확정을 덮지 않음 — v1 개정 규칙과 일관).

### 파일 읽기 실패
v1 `KnownAppResolver`와 동일 — 없거나 파싱 실패한 파일은 조용히 건너뜀. 샌드박스 컨테이너 접근 거부도 마찬가지(로그만).

## 5. 인벤토리 (B) — InventoryBuilder + 창

### InventoryBuilder (Engine)
`Sources/Engine/InventoryBuilder.swift`. 모든 소스를 모아 조합별 목록을 만든다.
```swift
public struct InventoryEntry: Hashable {
    public let combo: KeyCombo
    public let owners: [Owner]        // 1개 = 정상, 2+ = 충돌
    public let evidence: [Evidence]   // 소스 뱃지·근거용
    public var isConflict: Bool { Set(owners.map(\.identity)).count > 1 }
}

public enum InventoryBuilder {
    public static func build(_ evidence: [Evidence]) -> [InventoryEntry]
}
```
입력: 모든 Resolver가 "탐침 없이 전량"으로 낸 증거의 합집합. 조합(`KeyCombo`)으로 그룹핑 → 각 그룹을 `uniqueOwners`(v1 `Owner.identity` 병합 재사용)로 소유자 집계. 정렬: 충돌 먼저, 그다음 수정자·keyCode 순.

### 전량 열거 인터페이스
Resolver는 지금 "이 조합에 해당하는 증거"만 낸다. 인벤토리는 "전량"이 필요하므로 별도 프로토콜을 추가한다:
```swift
public protocol Enumerable {
    func allEvidence() -> [Evidence]
}
```
- `SystemHotkeyResolver`: 활성 심볼릭 핫키 전체 → certain 증거들.
- `KnownAppResolver`: 파서가 낸 (액션, 조합) 전부 → high/low 증거들.
- `HeuristicScanResolver`: 스캔한 모든 패턴 → medium 증거들.
- `CarbonOccupancyResolver`, `ReactionResolver`: `Enumerable` 미구현(전량 열거 불가/무의미) → 인벤토리에서 제외.

`resolve(_:probe:)`는 v1 그대로 두고 `allEvidence()`를 병행 추가(대부분 내부 로직 공유).

### 인벤토리 창 (App)
`Sources/HotkeyDetective/Views/InventoryWindow.swift`. `Window`(SwiftUI, macOS 14+) 또는 `NSWindow` 래핑. 팝오버 하단 "전체 단축키 보기" 버튼으로 연다.
- 상단: 제목 + "등록 N · 충돌 M" 요약, 검색 필드(조합·앱), "충돌만" 토글.
- 표: `조합(모노 글리프) | 소유자(앱·액션) | 소스 뱃지`. 충돌 행은 `bg-danger` 배경으로 상단 고정.
- 소스 뱃지: 시스템(accent) / 파서(accent) / 스캔(중립 회색) — 스캔이 약한 신호임을 색으로 암시.
- 데이터: `@MainActor InventoryModel`이 `allEvidence()` 수집 → `InventoryBuilder.build` → 필터/검색 적용. 앱·단축키 변경 감지는 v2 범위 밖(창 열 때 1회 계산 + 수동 새로고침 버튼).

## 6. UI 리디자인 (공통 비주얼 언어)

목업(2026-08-24 승인)의 언어를 팝오버·창에 공통 적용:
- 조합은 모노스페이스 글리프, 큰 크기.
- 소스 뱃지(시스템/파서/스캔) 일관.
- 충돌 = 주황/빨강 계열 통일(`contested`, 인벤토리 충돌 행).
- `VerdictView`를 이 톤으로 손봄: 헤드라인·근거 목록에 소스 뱃지 도입, 글리프 강조.
- 색·간격은 다크모드 대응(기존 SwiftUI 시스템 색 유지).

## 7. 데이터 흐름

**탐침(변경):** 기존 4 Resolver + `HeuristicScanResolver` → 증거 합집합 → `VerdictBuilder`(v1 그대로). 미지 앱이 스캔에 걸리면 `likely`로 승격.

**인벤토리(신규):** 창 열기 → `InventoryModel`이 `Enumerable` Resolver들의 `allEvidence()` 수집 → `InventoryBuilder.build` → 필터 → 표.

## 8. 모듈 변경 요약

```
Engine/
  Resolvers/HeuristicScanResolver.swift   [신규]
  InventoryBuilder.swift                  [신규]
  Resolver.swift                          [+Enumerable 프로토콜]
  Resolvers/SystemHotkeyResolver.swift    [+allEvidence]
  Resolvers/KnownApps/KnownAppResolver.swift [+allEvidence, +KnownApps.parserBundleIDs]
Probe/
  RunningAppsProvider.swift               [신규 — ScannableApp 생성]
HotkeyDetective/
  Views/InventoryWindow.swift             [신규]
  InventoryModel.swift                    [신규]
  ProbeSession.swift                      [+HeuristicScanResolver 편입]
  Views/VerdictView.swift                 [리디자인]
  HotkeyDetectiveApp.swift                [+Window 씬, "전체 단축키 보기"]
```

## 9. 테스트

- `HeuristicScanResolverTests`: KeyboardShortcuts 패턴, MAS 패턴, 배타 제외(파서 담당 앱은 스캔 안 됨), 중첩 plist 재귀, 깨진 파일 무시. 픽스처는 스파이크에서 확인한 실제 형태.
- `InventoryBuilderTests`: 단일 소유자/충돌 분류, 소스별 증거 병합, 정렬(충돌 우선), `Owner.identity` 병합 일관성.
- `Enumerable` 각 구현: 전량 열거가 `resolve` 결과와 모순 없는지(같은 조합 조회 시 부분집합).
- 수동: Maccy/Rectangle 실행 상태에서 인벤토리 창에 두 앱 항목이 뜨는지, ⌃Space가 충돌 행으로 상단에 오는지.

## 10. 범위 밖 (v2)

SkyLight private API, 배포/공증 DMG, Sparkle 자동 업데이트, 실시간 단축키 변경 감지, Alfred/1Password 정밀 파서(스캐너가 부분 커버).

## 11. 미해결/검증 항목

- 샌드박스 앱 컨테이너 plist 최초 읽기 시 macOS "다른 앱 데이터 접근" 프롬프트 — 스캔 대상이 많으면 프롬프트가 반복될 수 있음. 실측 후 UX 결정(일괄 안내 or 스캔을 사용자 명시 동작으로).
- `Enumerable`을 `SystemHotkeyResolver`가 구현할 때 기본값 테이블 전량을 낼지, plist 활성분만 낼지 — 인벤토리에 "기본값이지만 비활성"을 보일지 결정 필요.
- 인벤토리 창의 새로고침 정책(수동 vs 앱 실행/설정 변경 관찰).
