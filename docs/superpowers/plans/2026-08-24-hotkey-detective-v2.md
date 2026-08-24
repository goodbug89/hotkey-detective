# HotkeyDetective v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 범용 plist 스캐너로 미지 앱 핫키를 탐지하고(A), 전체 단축키를 훑는 인벤토리 창을 추가하며(B), 팝오버/창을 공통 비주얼 언어와 탐정극 애니메이션으로 리디자인한다.

**Architecture:** Engine에 `HeuristicScanResolver`(범용 패턴 스캐너)와 `InventoryBuilder`(전 소스 병합)를 추가하고, 전량 열거용 `Enumerable` 프로토콜을 도입한다. Probe에 `RunningAppsProvider`(스캔 대상 앱 수집)를 추가한다. App에 별도 인벤토리 `Window` 씬과 리디자인된 `VerdictView`/`RadarView`를 추가한다. v1의 `resolve(_:probe:)` 경로와 `VerdictBuilder`/`Owner.identity` 병합은 그대로 재사용한다.

**Tech Stack:** Swift 5 (툴체인 6.x), SwiftUI (`MenuBarExtra` + `Window`, macOS 14), XCTest, `swift build`/`swift test`, `Scripts/bundle.sh`(Developer ID 서명).

**Spec:** `docs/superpowers/specs/2026-08-24-hotkey-detective-v2-design.md`

## Global Constraints

- 최소 OS: **macOS 14**; `Engine` 타깃은 Foundation(+`os`)만 import — AppKit/CoreGraphics 금지
- `Probe`는 AppKit/CoreGraphics/Carbon 가능; `HotkeyDetective`(App)는 SwiftUI
- 스캐너 신뢰도는 항상 `.medium` (정밀 파서 `.high`보다 약함 — 시스템 `certain`을 덮지 않아야 함)
- bundleID 단위 배타 배정: 정밀 파서 담당 앱(`KnownApps.parserBundleIDs`)은 스캐너에서 제외
- 스캐너 패턴 2종: `KeyboardShortcuts_*` = `{"carbonKeyCode":N,"carbonModifiers":M}`(Carbon 비트), 딕셔너리 `{keyCode, modifierFlags|modifierMask}`(CG 비트)
- 파일 없음/파싱 실패 = 조용히 빈 배열 + `os_log(.debug)`, 사용자 오류 없음
- 애니메이션은 `@Environment(\.accessibilityReduceMotion)` 존중 — 켜지면 즉시 전환
- UI 문자열 한국어; 소스 뱃지 = 시스템 / 파서 / 스캔
- 커밋 메시지 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- 기존 테스트(현재 56개)는 계속 통과해야 함

## 파일 구조

```
Sources/Engine/
  Resolver.swift                          # +protocol Enumerable
  Resolvers/HeuristicScanResolver.swift   # 신규: ScannableApp, HeuristicScanResolver
  Resolvers/SystemHotkeyResolver.swift    # +Enumerable
  Resolvers/KnownApps/KnownAppResolver.swift # +Enumerable, +KnownApps.parserBundleIDs
  InventoryBuilder.swift                  # 신규: InventoryEntry, InventoryBuilder
Sources/Probe/
  RunningAppsProvider.swift               # 신규: 실행 중 앱 → [ScannableApp]
Sources/HotkeyDetective/
  ProbeSession.swift                      # +HeuristicScanResolver 편입
  InventoryModel.swift                    # 신규: @MainActor, allPairs 수집
  Views/InventoryWindow.swift             # 신규: 창 + 표 + 검색/필터
  Views/SourceBadge.swift                 # 신규: 공통 소스 뱃지
  Views/RadarView.swift                   # 신규: 레이더 스윕
  Views/VerdictView.swift                 # 리디자인 + 캐스케이드/판정별 트랜지션
  Views/ProbeView.swift                   # ListeningView가 RadarView 사용
  HotkeyDetectiveApp.swift                # +Window 씬, "전체 단축키 보기" 버튼
Tests/EngineTests/
  HeuristicScanResolverTests.swift        # 신규
  InventoryBuilderTests.swift             # 신규
  EnumerableTests.swift                   # 신규
  Fixtures/scan-*.plist                   # 신규 픽스처
```

---

### Task 1: Enumerable 프로토콜 + KnownApps.parserBundleIDs

**Files:**
- Modify: `Sources/Engine/Resolver.swift` (파일 끝에 프로토콜 추가)
- Modify: `Sources/Engine/Resolvers/KnownApps/KnownAppResolver.swift` (`KnownApps` enum에 정적 프로퍼티)
- Test: `Tests/EngineTests/EnumerableTests.swift`

**Interfaces:**
- Consumes: `Evidence`, `Resolver`, `KeyCombo`, `KnownAppResolver`, `KnownApps.rectangle/maccy/raycast`
- Produces: `protocol Enumerable { func allPairs() -> [(KeyCombo, Evidence)] }` + `extension Enumerable { func allEvidence() -> [Evidence] }`, `KnownApps.parserBundleIDs: Set<String>`, `KnownAppResolver: Enumerable`

- [ ] **Step 1: 실패 테스트 작성**

`Tests/EngineTests/EnumerableTests.swift`:
```swift
import XCTest
@testable import Engine

final class EnumerableTests: XCTestCase {
    struct Running: RunningAppChecker { let ids: Set<String>; func isRunning(bundleID: String) -> Bool { ids.contains(bundleID) } }
    func fixture(_ n: String) -> URL { Bundle.module.url(forResource: n, withExtension: "plist", subdirectory: "Fixtures")! }

    func testParserBundleIDsCoversThreeApps() {
        XCTAssertEqual(KnownApps.parserBundleIDs,
                       ["com.knollsoft.Rectangle", "org.p0deje.Maccy", "com.raycast.macos"])
    }

    func testKnownAppResolverAllPairsListEveryShortcutWithCombo() {
        let r = KnownAppResolver(descriptor: KnownApps.maccy, fileURL: fixture("maccy"), running: Running(ids: ["org.p0deje.Maccy"]))
        let pairs = r.allPairs()
        // maccy 픽스처에는 popup 하나만 있다
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.0, KeyCombo(keyCode: 9, modifiers: [.command, .shift]))
        XCTAssertEqual(pairs.first?.1.owner, .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"))
        XCTAssertEqual(pairs.first?.1.confidence, .high)
    }

    func testAllEvidenceDefaultIsAllPairsValues() {
        let r = KnownAppResolver(descriptor: KnownApps.maccy, fileURL: fixture("maccy"), running: Running(ids: ["org.p0deje.Maccy"]))
        XCTAssertEqual(r.allEvidence(), r.allPairs().map(\.1))
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter EnumerableTests`
Expected: 컴파일 실패 (`Enumerable`, `parserBundleIDs`, `allPairs` 미정의)

- [ ] **Step 3: 구현**

`Sources/Engine/Resolver.swift` 끝에 추가:
```swift
/// 탐침(특정 조합) 대신 이 Resolver가 아는 모든 단축키를 (조합, 증거) 페어로 낸다. 인벤토리용.
/// 조합을 함께 내는 이유: Evidence에는 조합이 없어 인벤토리가 조합별로 그룹핑할 수 없기 때문.
public protocol Enumerable {
    func allPairs() -> [(KeyCombo, Evidence)]
}
public extension Enumerable {
    func allEvidence() -> [Evidence] { allPairs().map(\.1) }
}
```

`KnownAppResolver`를 `: Resolver, Enumerable`로 바꾸고, `resolve`와 `allPairs`가 공통 페어 생성 로직을 공유하도록 기존 `resolve` 본문을 아래로 교체:
```swift
    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        allPairs().filter { $0.0 == combo }.map { $0.1 }
    }

    public func allPairs() -> [(KeyCombo, Evidence)] {
        guard let data = try? Data(contentsOf: fileURL),
              let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            Self.log.debug("\(descriptor.name): 설정 파일 없음/파싱 실패 \(fileURL.path)")
            return []
        }
        let isRunning = running.isRunning(bundleID: descriptor.bundleID)
        return descriptor.parse(root).map { hit in
            (hit.combo, Evidence(source: name,
                owner: .app(bundleID: descriptor.bundleID, name: descriptor.name, action: hit.action),
                confidence: isRunning ? .high : .low,
                rationale: isRunning
                    ? "\(descriptor.name) 단축키 '\(hit.action)' = \(hit.combo.display)"
                    : "\(descriptor.name) 단축키 '\(hit.action)' = \(hit.combo.display) — 현재 실행 중 아님, 실행 시 충돌 예상"))
        }
    }
```

`KnownApps` enum에 추가:
```swift
    public static let parserBundleIDs: Set<String> = ["com.knollsoft.Rectangle", "org.p0deje.Maccy", "com.raycast.macos"]
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter EnumerableTests`
Expected: 3 PASS. 그리고 `swift test` 전체 → 기존 56개 유지 + 신규 3 = 59 PASS.

- [ ] **Step 5: 커밋**

```bash
git add -A && git commit -m "feat(engine): Enumerable protocol and KnownApps.parserBundleIDs" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: SystemHotkeyResolver Enumerable 채택

**Files:**
- Modify: `Sources/Engine/Resolvers/SystemHotkeyResolver.swift`
- Test: `Tests/EngineTests/EnumerableTests.swift` (테스트 추가)

**Interfaces:**
- Consumes: `Enumerable`, `SystemHotkeyResolver`, `SymbolicHotKeyDefaults`, `effectiveEntries()`
- Produces: `SystemHotkeyResolver: Resolver, Enumerable` — `allPairs()`가 활성 심볼릭 핫키 전량을 (조합, certain 증거)로

- [ ] **Step 1: 실패 테스트 작성**

`EnumerableTests.swift`에 추가:
```swift
    func testSystemResolverAllPairsListEnabledOnly() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        let pairs = r.allPairs()
        // 전부 certain, owner는 시스템
        XCTAssertTrue(pairs.allSatisfy { $0.1.confidence == .certain })
        XCTAssertTrue(pairs.allSatisfy { if case .system = $0.1.owner { return true } else { return false } })
        // ⇧⌘4 (영역 스크린샷)이 조합과 함께 목록에 있어야
        XCTAssertTrue(pairs.contains { $0.0 == KeyCombo(keyCode: 21, modifiers: [.command, .shift])
                                       && $0.1.owner == .system(feature: "영역 스크린샷") })
    }

    func testSystemResolverAllPairsExcludeDisabled() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-disabled28"))
        // disabled28 픽스처는 항목 30(영역 스크린샷)을 비활성화 → 목록에 없어야
        XCTAssertFalse(r.allPairs().contains { $0.1.owner == .system(feature: "영역 스크린샷") })
    }
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter EnumerableTests`
Expected: 컴파일 실패 (`SystemHotkeyResolver`에 `allPairs` 없음)

- [ ] **Step 3: 구현**

`SystemHotkeyResolver`를 `: Resolver, Enumerable`로 바꾸고, `resolve`가 `allPairs`를 필터하도록 정리:
```swift
    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        allPairs().filter { $0.0 == combo }.map { $0.1 }
    }

    public func allPairs() -> [(KeyCombo, Evidence)] {
        effectiveEntries().compactMap { e in
            guard e.enabled, let combo = e.combo else { return nil }
            return (combo, Evidence(source: name,
                                    owner: .system(feature: SymbolicHotKeyDefaults.feature(for: e.id)),
                                    confidence: .certain,
                                    rationale: "symbolichotkeys 항목 \(e.id)이(가) \(combo.display)으로 활성화됨"))
        }
    }
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter EnumerableTests` → 5 PASS. 전체 `swift test` → 회귀 없음.

> 주의: v1 `symbolichotkeys-disabled28.plist` 픽스처가 항목 30(영역 스크린샷, ⇧⌘4)을 실제로 비활성화하는지 확인. 아니면 이 태스크에서 픽스처에 `<key>30</key><dict><key>enabled</key><false/></dict>`가 있는지 점검하고, 없으면 테스트가 검증하려는 조합을 실제 비활성 항목으로 맞춘다.

- [ ] **Step 5: 커밋**

```bash
git add -A && git commit -m "feat(engine): SystemHotkeyResolver conforms to Enumerable" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: HeuristicScanResolver

**Files:**
- Create: `Sources/Engine/Resolvers/HeuristicScanResolver.swift`
- Create: `Tests/EngineTests/Fixtures/scan-keyboardshortcuts.plist`, `scan-mas.plist`, `scan-nested.plist`, `scan-broken.plist`
- Test: `Tests/EngineTests/HeuristicScanResolverTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`, `Modifiers(carbon:)`, `Modifiers(cgFlags:)`, `Evidence`, `Owner.app`, `Resolver`, `Enumerable`
- Produces:
  - `struct ScannableApp: Hashable { bundleID: String; name: String; plistURLs: [URL] }`
  - `struct HeuristicScanResolver: Resolver, Enumerable` — `init(apps: [ScannableApp], excludedBundleIDs: Set<String>)`, `allPairs()` 구현
  - `name == "설정 스캔"`, 증거 confidence `.medium`

- [ ] **Step 1: 픽스처 작성**

`scan-keyboardshortcuts.plist` (Maccy류 형식, bundleID는 테스트에서 지정):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>KeyboardShortcuts_popup</key><string>{"carbonKeyCode":8,"carbonModifiers":768}</string>
  <key>KeyboardShortcuts_pin</key><string>{"carbonModifiers":2048,"carbonKeyCode":35}</string>
  <key>showFooter</key><true/>
</dict></plist>
```

`scan-mas.plist` (Rectangle류 사용자 지정분):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>toggleTodo</key><dict><key>keyCode</key><integer>11</integer><key>modifierFlags</key><integer>786432</integer></dict>
  <key>somethingElse</key><dict><key>keyCode</key><integer>45</integer><key>modifierMask</key><integer>1572864</integer></dict>
  <key>notAShortcut</key><dict><key>foo</key><integer>1</integer></dict>
</dict></plist>
```

`scan-nested.plist` (중첩 딕셔너리 안의 패턴 — 재귀 검증):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>preferences</key><dict>
    <key>KeyboardShortcuts_open</key><string>{"carbonKeyCode":31,"carbonModifiers":768}</string>
  </dict>
</dict></plist>
```

`scan-broken.plist`: 내용 `not a plist at all`.

- [ ] **Step 2: 실패 테스트 작성**

`Tests/EngineTests/HeuristicScanResolverTests.swift`:
```swift
import XCTest
@testable import Engine

final class HeuristicScanResolverTests: XCTestCase {
    func fx(_ n: String) -> URL { Bundle.module.url(forResource: n, withExtension: "plist", subdirectory: "Fixtures")! }
    func app(_ bid: String, _ name: String, _ fixtures: [String]) -> ScannableApp {
        ScannableApp(bundleID: bid, name: name, plistURLs: fixtures.map(fx))
    }

    func testKeyboardShortcutsPattern() {
        let r = HeuristicScanResolver(apps: [app("com.example.Clip", "Clip", ["scan-keyboardshortcuts"])], excludedBundleIDs: [])
        // popup = ⌘⇧C (keyCode 8, carbon 768 = cmd256|shift512)
        let e = r.resolve(KeyCombo(keyCode: 8, modifiers: [.command, .shift]), probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .app(bundleID: "com.example.Clip", name: "Clip", action: "popup"))
        XCTAssertEqual(e[0].confidence, .medium)
        XCTAssertEqual(e[0].source, "설정 스캔")
    }

    func testMASPattern_keyCodeModifierFlags() {
        let r = HeuristicScanResolver(apps: [app("com.example.Win", "Win", ["scan-mas"])], excludedBundleIDs: [])
        // toggleTodo keyCode 11 modifierFlags 786432 = ctrl(1<<18)|opt(1<<19)
        let e = r.resolve(KeyCombo(keyCode: 11, modifiers: [.control, .option]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.example.Win", name: "Win", action: "toggleTodo"))
    }

    func testMASPattern_modifierMaskAlias() {
        let r = HeuristicScanResolver(apps: [app("com.example.Win", "Win", ["scan-mas"])], excludedBundleIDs: [])
        // somethingElse keyCode 45 modifierMask 1572864 = opt(1<<19)|cmd(1<<20)
        let e = r.resolve(KeyCombo(keyCode: 45, modifiers: [.option, .command]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.example.Win", name: "Win", action: "somethingElse"))
    }

    func testNestedDictRecursion() {
        let r = HeuristicScanResolver(apps: [app("com.example.N", "N", ["scan-nested"])], excludedBundleIDs: [])
        // open keyCode 31 carbon 768
        let e = r.resolve(KeyCombo(keyCode: 31, modifiers: [.command, .shift]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.example.N", name: "N", action: "open"))
    }

    func testExcludedBundleIsSkipped() {
        let r = HeuristicScanResolver(apps: [app("org.p0deje.Maccy", "Maccy", ["scan-keyboardshortcuts"])],
                                      excludedBundleIDs: ["org.p0deje.Maccy"])
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 8, modifiers: [.command, .shift]), probe: nil).isEmpty)
        XCTAssertTrue(r.allEvidence().isEmpty)
    }

    func testBrokenAndMissingFilesGiveNothing() {
        let r = HeuristicScanResolver(apps: [app("com.example.B", "B", ["scan-broken"])], excludedBundleIDs: [])
        XCTAssertTrue(r.allEvidence().isEmpty)
        let miss = HeuristicScanResolver(apps: [ScannableApp(bundleID: "x", name: "X", plistURLs: [URL(fileURLWithPath: "/nope.plist")])], excludedBundleIDs: [])
        XCTAssertTrue(miss.allEvidence().isEmpty)
    }

    func testUsesFirstExistingPlistURL() {
        let miss = URL(fileURLWithPath: "/nope.plist")
        let r = HeuristicScanResolver(apps: [ScannableApp(bundleID: "com.example.Clip", name: "Clip", plistURLs: [miss, fx("scan-keyboardshortcuts")])], excludedBundleIDs: [])
        XCTAssertEqual(r.allEvidence().count, 2)   // popup + pin
    }

    func testAllPairsCountsEveryShortcut() {
        let r = HeuristicScanResolver(apps: [app("com.example.Clip", "Clip", ["scan-keyboardshortcuts"])], excludedBundleIDs: [])
        let pairs = r.allPairs()
        XCTAssertEqual(pairs.count, 2)  // popup, pin (showFooter는 무시)
        XCTAssertTrue(pairs.contains { $0.0 == KeyCombo(keyCode: 8, modifiers: [.command, .shift]) })
    }
}
```

- [ ] **Step 3: 실패 확인**

Run: `swift test --filter HeuristicScanResolverTests`
Expected: 컴파일 실패

- [ ] **Step 4: 구현**

`Sources/Engine/Resolvers/HeuristicScanResolver.swift`:
```swift
import Foundation
import os

public struct ScannableApp: Hashable {
    public let bundleID: String
    public let name: String
    public let plistURLs: [URL]
    public init(bundleID: String, name: String, plistURLs: [URL]) {
        self.bundleID = bundleID; self.name = name; self.plistURLs = plistURLs
    }
    /// 존재하는 첫 plist
    var firstExisting: URL? { plistURLs.first { FileManager.default.fileExists(atPath: $0.path) } }
}

/// 실행 중 앱의 plist를 훑어 알려진 두 직렬화 패턴으로 단축키를 추정한다.
public struct HeuristicScanResolver: Resolver, Enumerable {
    public let name = "설정 스캔"
    let apps: [ScannableApp]
    let excludedBundleIDs: Set<String>
    private static let log = Logger(subsystem: "HotkeyDetective", category: "scan")

    public init(apps: [ScannableApp], excludedBundleIDs: Set<String>) {
        self.apps = apps; self.excludedBundleIDs = excludedBundleIDs
    }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        scanPairs { $0 == combo }.map { $0.1 }
    }

    public func allPairs() -> [(KeyCombo, Evidence)] {
        scanPairs { _ in true }
    }

    private func scanPairs(_ include: (KeyCombo) -> Bool) -> [(KeyCombo, Evidence)] {
        var out: [(KeyCombo, Evidence)] = []
        for app in apps where !excludedBundleIDs.contains(app.bundleID) {
            guard let url = app.firstExisting,
                  let data = try? Data(contentsOf: url),
                  let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
                Self.log.debug("scan: 건너뜀 \(app.bundleID)")
                continue
            }
            for (action, combo) in extract(root) where include(combo) {
                out.append((combo, Evidence(source: name,
                    owner: .app(bundleID: app.bundleID, name: app.name, action: action),
                    confidence: .medium,
                    rationale: "\(app.name) 설정에서 '\(action)' = \(combo.display) 패턴 발견")))
            }
        }
        return out.sorted { $0.1.rationale < $1.1.rationale }
    }

    /// plist 재귀 순회 → (액션, 조합) 목록. 두 패턴만 인식.
    private func extract(_ any: Any, key: String = "") -> [(action: String, combo: KeyCombo)] {
        var found: [(String, KeyCombo)] = []
        if let dict = any as? [String: Any] {
            // MAS 패턴: keyCode + modifierFlags|modifierMask (CG 비트)
            if let k = (dict["keyCode"] as? NSNumber)?.uint16Value,
               let m = ((dict["modifierFlags"] ?? dict["modifierMask"]) as? NSNumber)?.uint64Value {
                found.append((key, KeyCombo(keyCode: k, modifiers: Modifiers(cgFlags: m))))
            }
            for (k, v) in dict {
                // KeyboardShortcuts 패턴: 접두어 키 + JSON 문자열 (Carbon 비트)
                if k.hasPrefix("KeyboardShortcuts_"), let s = v as? String,
                   let d = s.data(using: .utf8),
                   let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                   let kc = (j["carbonKeyCode"] as? NSNumber)?.uint16Value,
                   let cm = (j["carbonModifiers"] as? NSNumber)?.uint32Value {
                    found.append((String(k.dropFirst("KeyboardShortcuts_".count)),
                                  KeyCombo(keyCode: kc, modifiers: Modifiers(carbon: cm))))
                } else {
                    found.append(contentsOf: extract(v, key: k))
                }
            }
        } else if let arr = any as? [Any] {
            for v in arr { found.append(contentsOf: extract(v, key: key)) }
        }
        return found
    }
}
```

- [ ] **Step 5: 통과 확인**

Run: `swift test --filter HeuristicScanResolverTests` → 8 PASS. 전체 `swift test` → 회귀 없음.

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(engine): HeuristicScanResolver scans plists for two shortcut patterns" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: InventoryBuilder

**Files:**
- Create: `Sources/Engine/InventoryBuilder.swift`
- Test: `Tests/EngineTests/InventoryBuilderTests.swift`

**Interfaces:**
- Consumes: `Evidence`, `Owner`, `Owner.identity`, `KeyCombo`
- Produces:
  - `struct InventoryEntry: Hashable { combo: KeyCombo; owners: [Owner]; evidence: [Evidence]; isConflict: Bool }`
  - `enum InventoryBuilder { static func build(_ evidence: [(KeyCombo, Evidence)]) -> [InventoryEntry] }`

> 설계 결정(스펙 5절 정정): `Evidence`에는 조합이 없으므로 `build`는 `[(KeyCombo, Evidence)]` 페어를 받는다. 페어는 Task 1에서 도입한 `Enumerable.allPairs()`가 공급한다. 이 Task는 순수 병합 로직만 다룬다.

- [ ] **Step 1: 실패 테스트 작성**

`Tests/EngineTests/InventoryBuilderTests.swift`:
```swift
import XCTest
@testable import Engine

final class InventoryBuilderTests: XCTestCase {
    let a4 = KeyCombo(keyCode: 21, modifiers: [.command, .shift])
    let space = KeyCombo(keyCode: 49, modifiers: [.control])
    func ev(_ owner: Owner, _ c: Confidence = .high, src: String = "t") -> Evidence {
        Evidence(source: src, owner: owner, confidence: c, rationale: "r")
    }
    let sys = Owner.system(feature: "이전 입력 소스 선택")
    let maccy = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "togglePreview")
    let scr = Owner.system(feature: "영역 스크린샷")

    func testSingleOwnerIsNotConflict() {
        let entries = InventoryBuilder.build([(a4, ev(scr, .certain))])
        XCTAssertEqual(entries.count, 1)
        XCTAssertFalse(entries[0].isConflict)
        XCTAssertEqual(entries[0].owners, [scr])
    }

    func testDifferentOwnersSameComboIsConflict() {
        let entries = InventoryBuilder.build([(space, ev(sys, .certain)), (space, ev(maccy, .medium))])
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isConflict)
        XCTAssertEqual(Set(entries[0].owners.map(\.identity)), [sys.identity, maccy.identity])
        XCTAssertEqual(entries[0].evidence.count, 2)
    }

    func testSameOwnerActionMergesNoConflict() {
        let noAction = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: nil)
        let entries = InventoryBuilder.build([(space, ev(noAction)), (space, ev(maccy))])
        XCTAssertFalse(entries[0].isConflict, "같은 앱은 한 소유자")
        XCTAssertEqual(entries[0].owners.count, 1)
        XCTAssertEqual(entries[0].owners[0], maccy, "액션 있는 쪽 유지")
    }

    func testConflictsSortedFirst() {
        let entries = InventoryBuilder.build([(a4, ev(scr, .certain)),
                                              (space, ev(sys, .certain)), (space, ev(maccy, .medium))])
        XCTAssertTrue(entries[0].isConflict)
        XCTAssertEqual(entries[0].combo, space)
        XCTAssertFalse(entries[1].isConflict)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter InventoryBuilderTests` → 컴파일 실패

- [ ] **Step 3: 구현**

`Sources/Engine/InventoryBuilder.swift`:
```swift
import Foundation

public struct InventoryEntry: Hashable {
    public let combo: KeyCombo
    public let owners: [Owner]
    public let evidence: [Evidence]
    public var isConflict: Bool { Set(owners.map(\.identity)).count > 1 }
    public init(combo: KeyCombo, owners: [Owner], evidence: [Evidence]) {
        self.combo = combo; self.owners = owners; self.evidence = evidence
    }
}

public enum InventoryBuilder {
    public static func build(_ pairs: [(KeyCombo, Evidence)]) -> [InventoryEntry] {
        // 조합별 그룹핑 (KeyCombo는 Hashable)
        var byCombo: [KeyCombo: [Evidence]] = [:]
        var order: [KeyCombo] = []
        for (combo, e) in pairs {
            if byCombo[combo] == nil { order.append(combo) }
            byCombo[combo, default: []].append(e)
        }
        let entries = order.map { combo -> InventoryEntry in
            let evs = byCombo[combo]!
            return InventoryEntry(combo: combo, owners: mergeOwners(evs), evidence: evs)
        }
        // 충돌 먼저, 그다음 수정자 rawValue → keyCode 안정 정렬
        return entries.sorted { l, r in
            if l.isConflict != r.isConflict { return l.isConflict }
            if l.combo.modifiers.rawValue != r.combo.modifiers.rawValue {
                return l.combo.modifiers.rawValue < r.combo.modifiers.rawValue
            }
            return l.combo.keyCode < r.combo.keyCode
        }
    }

    /// v1 Owner.identity 병합 규칙과 동일: 앱은 bundleID, 시스템은 기능명. 액션 있는 쪽 유지.
    private static func mergeOwners(_ evidence: [Evidence]) -> [Owner] {
        var index: [String: Int] = [:], out: [Owner] = []
        for e in evidence {
            guard let o = e.owner else { continue }
            if let i = index[o.identity] {
                if case .app(_, _, nil) = out[i], case .app(_, _, .some) = o { out[i] = o }
            } else {
                index[o.identity] = out.count
                out.append(o)
            }
        }
        return out
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter InventoryBuilderTests` → 4 PASS. 전체 `swift test` → 회귀 없음.

- [ ] **Step 5: 커밋**

```bash
git add -A && git commit -m "feat(engine): InventoryBuilder groups evidence by combo, flags conflicts" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Probe — RunningAppsProvider

**Files:**
- Create: `Sources/Probe/RunningAppsProvider.swift`

**Interfaces:**
- Consumes: `ScannableApp` (Engine), `KnownApps.containerPrefs`/`prefs`
- Produces: `enum RunningAppsProvider { static func scannableApps() -> [ScannableApp] }`

> Probe 계층이라 단위 테스트 없음 — 빌드 + Task 8의 실기 검증으로 확인.

- [ ] **Step 1: 구현**

`Sources/Probe/RunningAppsProvider.swift`:
```swift
import AppKit
import Engine

public enum RunningAppsProvider {
    /// 실행 중인 모든 앱(백그라운드 에이전트 포함)을 스캔 대상으로. bundleID별 일반+컨테이너 plist 경로.
    public static func scannableApps() -> [ScannableApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bid = app.bundleIdentifier, let name = app.localizedName else { return nil }
            let prefs = home.appendingPathComponent("Library/Preferences/\(bid).plist")
            let container = home.appendingPathComponent("Library/Containers/\(bid)/Data/Library/Preferences/\(bid).plist")
            return ScannableApp(bundleID: bid, name: name, plistURLs: [prefs, container])
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

Run: `swift build`
Expected: 성공, 경고 0

- [ ] **Step 3: 커밋**

```bash
git add -A && git commit -m "feat(probe): RunningAppsProvider collects scannable apps with plist paths" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: ProbeSession에 스캐너 편입

**Files:**
- Modify: `Sources/HotkeyDetective/ProbeSession.swift` (`resolvers` 계산 프로퍼티)

**Interfaces:**
- Consumes: `HeuristicScanResolver`, `RunningAppsProvider.scannableApps()`, `KnownApps.parserBundleIDs`
- Produces: 탐침 경로에 스캐너 추가 (미지 앱이 `likely`로 승격)

- [ ] **Step 1: 구현**

`ProbeSession.swift`의 `resolvers`를 교체:
```swift
    var resolvers: [Resolver] {
        [SystemHotkeyResolver(),
         CarbonOccupancyResolver(registrar: CarbonHotKeyRegistrar()),
         ReactionResolver(),
         HeuristicScanResolver(apps: RunningAppsProvider.scannableApps(),
                               excludedBundleIDs: KnownApps.parserBundleIDs)]
        + KnownApps.all(running: WorkspaceRunningApps())
    }
```

- [ ] **Step 2: 빌드 + 회귀 테스트**

Run: `swift build && swift test`
Expected: 빌드 성공, 전체 테스트 회귀 없음.

- [ ] **Step 3: 커밋**

```bash
git add -A && git commit -m "feat(app): probe includes HeuristicScanResolver for unknown apps" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: InventoryModel + 인벤토리 창

**Files:**
- Create: `Sources/HotkeyDetective/InventoryModel.swift`
- Create: `Sources/HotkeyDetective/Views/SourceBadge.swift`
- Create: `Sources/HotkeyDetective/Views/InventoryWindow.swift`
- Modify: `Sources/HotkeyDetective/HotkeyDetectiveApp.swift` (`Window` 씬 + 열기 버튼)

**Interfaces:**
- Consumes: `InventoryBuilder`, `InventoryEntry`, `Enumerable`/`allPairs`, `SystemHotkeyResolver`, `KnownApps.all`, `HeuristicScanResolver`, `RunningAppsProvider`, `WorkspaceRunningApps`, `Owner`, `Evidence.source`
- Produces: `@MainActor final class InventoryModel: ObservableObject`, `InventoryWindow` View, `SourceBadge` View, `openWindow(id: "inventory")` 트리거

> 뷰는 화면 확인이 불가하므로 deliverable은 warning-free 빌드 + Task 12의 수동 체크리스트.

- [ ] **Step 1: SourceBadge**

`Sources/HotkeyDetective/Views/SourceBadge.swift`:
```swift
import SwiftUI

/// 증거 소스명 → 뱃지. 시스템/파서는 accent, 스캔은 중립.
struct SourceBadge: View {
    let source: String   // "시스템 단축키", "Rectangle 설정", "설정 스캔" 등
    var body: some View {
        let (label, tint) = style
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
    private var style: (String, Color) {
        if source.contains("스캔") { return ("스캔", .secondary) }
        if source.contains("시스템") { return ("시스템", .accentColor) }
        return ("파서", .accentColor)
    }
}
```

- [ ] **Step 2: InventoryModel**

`Sources/HotkeyDetective/InventoryModel.swift`:
```swift
import SwiftUI
import Engine
import Probe

@MainActor
final class InventoryModel: ObservableObject {
    @Published var entries: [InventoryEntry] = []
    @Published var query: String = ""
    @Published var conflictsOnly: Bool = false

    func reload() {
        let enumerables: [Enumerable] = [SystemHotkeyResolver(),
            HeuristicScanResolver(apps: RunningAppsProvider.scannableApps(),
                                  excludedBundleIDs: KnownApps.parserBundleIDs)]
            + KnownApps.all(running: WorkspaceRunningApps()).compactMap { $0 as? Enumerable }
        let pairs = enumerables.flatMap { $0.allPairs() }
        entries = InventoryBuilder.build(pairs)
    }

    var filtered: [InventoryEntry] {
        entries.filter { e in
            (!conflictsOnly || e.isConflict) &&
            (query.isEmpty
             || e.combo.display.localizedCaseInsensitiveContains(query)
             || e.owners.contains { $0.displayName.localizedCaseInsensitiveContains(query) })
        }
    }

    var conflictCount: Int { entries.filter(\.isConflict).count }
}
```

- [ ] **Step 3: InventoryWindow**

`Sources/HotkeyDetective/Views/InventoryWindow.swift`:
```swift
import SwiftUI
import Engine

struct InventoryWindow: View {
    @StateObject private var model = InventoryModel()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                Text("전체 단축키").font(.headline)
                Text("등록 \(model.entries.count) · 충돌 \(model.conflictCount)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                TextField("조합·앱 검색", text: $model.query).textFieldStyle(.roundedBorder).frame(width: 160)
                Toggle("충돌만", isOn: $model.conflictsOnly).toggleStyle(.button)
                Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
            }
            .padding(12)
            Divider()
            List(model.filtered, id: \.combo) { e in
                HStack(alignment: .top, spacing: 12) {
                    Text(e.combo.display)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(e.isConflict ? Color.orange : .primary)
                        .frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        if e.isConflict {
                            Label(e.owners.map(\.displayName).joined(separator: " · "), systemImage: "exclamationmark.triangle")
                                .font(.callout).foregroundStyle(.orange)
                        } else {
                            Text(e.owners.first?.displayName ?? "—").font(.callout)
                        }
                    }
                    Spacer()
                    if let src = e.evidence.first?.source { SourceBadge(source: src) }
                }
                .padding(.vertical, 3)
                .listRowBackground(e.isConflict ? Color.orange.opacity(0.08) : Color.clear)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear { model.reload() }
    }
}
```

- [ ] **Step 4: 창 씬 + 열기 버튼**

`HotkeyDetectiveApp.swift`의 `body`에 Window 씬 추가하고, `FooterMenu` 또는 `ProbeView`에 여는 버튼 추가:
```swift
    var body: some Scene {
        MenuBarExtra("HotkeyDetective", systemImage: "keyboard.badge.ellipsis") {
            RootView().environmentObject(session).frame(width: 360)
        }
        .menuBarExtraStyle(.window)
        Window("전체 단축키", id: "inventory") { InventoryWindow() }
    }
```
`FooterMenu`에 버튼(환경의 `openWindow` 사용):
```swift
    @Environment(\.openWindow) private var openWindow
    // HStack 안에 추가:
    Button("전체 단축키 보기") { openWindow(id: "inventory") }
        .buttonStyle(.link).font(.caption)
```

- [ ] **Step 5: 빌드 확인**

Run: `swift build`
Expected: 성공, 경고 0

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(app): inventory window with search, conflict filter, source badges" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: RadarView (레이더 스윕)

**Files:**
- Create: `Sources/HotkeyDetective/Views/RadarView.swift`
- Modify: `Sources/HotkeyDetective/Views/ProbeView.swift` (`ListeningView`가 RadarView 사용)

**Interfaces:**
- Consumes: `@Environment(\.accessibilityReduceMotion)`
- Produces: `RadarView` — 회전하는 스윕. reduce motion이면 정적 원.

- [ ] **Step 1: 구현**

`Sources/HotkeyDetective/Views/RadarView.swift`:
```swift
import SwiftUI

struct RadarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0
    static let period: Double = 1.4

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1).scaleEffect(0.6)
            if !reduceMotion {
                Rectangle()
                    .fill(LinearGradient(colors: [.accentColor.opacity(0.6), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 2)
                    .offset(y: -14)
                    .rotationEffect(.degrees(angle))
            }
            Circle().fill(Color.accentColor).frame(width: 8, height: 8)
        }
        .frame(width: 56, height: 56)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: Self.period).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
```

`ProbeView.swift`의 `ListeningView` 몸통에서 기존 펄스 Circle을 `RadarView()`로 교체(텍스트/취소 버튼은 유지).

- [ ] **Step 2: 빌드 확인**

Run: `swift build`
Expected: 성공, 경고 0

- [ ] **Step 3: 커밋**

```bash
git add -A && git commit -m "feat(app): radar sweep animation in listening state" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: VerdictView 리디자인 + 캐스케이드/판정별 트랜지션

**Files:**
- Modify: `Sources/HotkeyDetective/Views/VerdictView.swift`

**Interfaces:**
- Consumes: `Verdict`, `Evidence`, `SourceBadge`, `@Environment(\.accessibilityReduceMotion)`
- Produces: 근거 캐스케이드 등장, 판정별 헤드라인 트랜지션, 소스 뱃지·모노 글리프 적용

- [ ] **Step 1: 구현**

`VerdictView.swift`에서:
1. 큰 조합 텍스트를 `.font(.system(size: 34, weight: .semibold, design: .monospaced))`로.
2. 근거 목록의 각 행에 `SourceBadge(source: e.source)`를 신뢰도 점 옆에 추가.
3. 근거 등장에 캐스케이드: 각 행에 `.transition(.move(edge: .top).combined(with: .opacity))`, 등장 시 `@State private var appeared = false`를 `onAppear`에서 순차 지연으로 true. 상수:
```swift
    static let cascadeStagger: Double = 0.05
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0     // 몇 개의 근거를 표시했는지
```
`onAppear`에서 reduce motion이면 `shown = evidence.count`, 아니면:
```swift
    for i in evidence.indices {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Self.cascadeStagger) {
            withAnimation(.easeOut(duration: 0.2)) { shown = i + 1 }
        }
    }
```
근거 `ForEach`는 `verdict.evidence.prefix(shown)`만 렌더.
4. 판정별 헤드라인 반응: `@State private var pop = false`, `@State private var shake: CGFloat = 0`.
   - confirmed: `.scaleEffect(pop ? 1.0 : 1.15)`, onAppear에서 `withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = true }` (reduce motion이면 pop=true 즉시).
   - contested: `.offset(x: shake)`, onAppear에서 reduce motion 아니면 흔들기:
```swift
    withAnimation(.default) { shake = -6 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { shake = 6 } }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation { shake = 0 } }
```
   - free/likely/occupiedUnknown: 기본(변형 없음).

> 구현 시 상태 초기화가 조합마다 재실행되도록 `.id(combo)`를 VerdictView 루트에 부여해 새 결과에서 애니메이션이 다시 돈다.

- [ ] **Step 2: 빌드 확인**

Run: `swift build`
Expected: 성공, 경고 0

- [ ] **Step 3: 커밋**

```bash
git add -A && git commit -m "feat(app): verdict cascade, per-verdict reactions, source badges, mono glyph" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: 번들 재빌드 + 전체 회귀

**Files:** (없음 — 검증 태스크)

- [ ] **Step 1: 전체 테스트 10회 반복 (플레이크 확인)**

Run:
```bash
for i in $(seq 1 10); do swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1; done
```
Expected: 10회 모두 동일 개수, 0 failures.

- [ ] **Step 2: Developer ID 서명 번들**

Run: `pkill -x HotkeyDetective; Scripts/bundle.sh debug`
Expected: `signed with: Developer ID Application: …`, `built build/HotkeyDetective.app`

- [ ] **Step 3: 커밋 (변경 없으면 생략)**

변경 파일이 없으면 커밋 없음. 있으면:
```bash
git add -A && git commit -m "chore: v2 regression pass" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: 수동 검증 체크리스트 (사용자 협조)

**Files:** (없음 — 실기 검증. 스펙 11절 미해결 항목을 여기서 결정)

이 Task는 사용자가 앱을 실행해 확인해야 하는 항목이다. 구현자는 체크리스트를 `docs/superpowers/specs/2026-08-24-hotkey-detective-v2-design.md` 11절에 실측 결과로 기록한다.

- [ ] **Step 1: 스캐너 탐침** — Maccy 종료 후(정밀 파서 없는 상태를 흉내내기 어려우면) 임의의 KeyboardShortcuts 앱(예: Ice, CleanShot 설치)의 조합을 탐침 → `likely`로 소유자가 나오는지. 안 나오면 해당 앱 plist 경로/패턴을 로그로 확인.
- [ ] **Step 2: 인벤토리 창** — "전체 단축키 보기" → 창에 시스템 항목 + Rectangle/Maccy 항목이 뜨는지, ⌃Space가 충돌 행으로 상단에 오는지, 검색·"충돌만" 필터·새로고침 동작.
- [ ] **Step 3: 애니메이션** — 탐침 시 레이더 스윕 → 결과에서 근거 캐스케이드 → confirmed 바운스 / contested 흔들림 확인. 시스템 설정 "동작 줄이기" 켠 뒤 애니메이션이 생략되고 즉시 전환되는지.
- [ ] **Step 4: 샌드박스 프롬프트 빈도** — 인벤토리 로드 시 "다른 앱 데이터 접근" 프롬프트가 몇 번 뜨는지 관찰. 반복이 과하면 스펙 11절에 기록하고 후속 결정(스캔을 명시적 동작으로 게이트).
- [ ] **Step 5: 결과 기록** — 위 관찰을 스펙 11절에 `[검증됨 날짜]` 형식으로 추가하고 커밋.

---

## Self-Review 결과

- **스펙 커버리지:** 2절(스파이크 근거, 코드 아님) · 3절 결정(Task 1·3·7) · 4절 스캐너(Task 3·5·6) · 5절 인벤토리(Task 4·7) · 6절 UI 리디자인(Task 7·9) · 6.1절 애니메이션(Task 8·9) · 7절 데이터 흐름(Task 6·7) · 8절 모듈 변경(전 태스크) · 9절 테스트(Task 1–4 단위, Task 7–9 빌드, Task 11 수동) · 11절 미해결(Task 11에서 실측 기록).
- **스펙과의 차이(정정):** 스펙 5절은 `InventoryBuilder.build(_ evidence: [Evidence])`로 적었으나 `Evidence`에 조합이 없어 병합 불가 — `build(_ pairs: [(KeyCombo, Evidence)])`로 바꾸고 `Enumerable`을 처음부터 `allPairs() -> [(KeyCombo, Evidence)]`로 정의(Task 1), `allEvidence()`는 기본 구현. 실행 후 스펙 5절을 이 시그니처로 갱신할 것.
- **타입 일관성:** `Enumerable.allPairs() -> [(KeyCombo, Evidence)]`, `HeuristicScanResolver(apps:excludedBundleIDs:)`, `ScannableApp(bundleID:name:plistURLs:)`, `InventoryEntry(combo:owners:evidence:)`, `InventoryBuilder.build(_:)`, `KnownApps.parserBundleIDs`, `RunningAppsProvider.scannableApps()`, `InventoryModel`, `SourceBadge`, `RadarView` — 전 태스크에서 동일 사용. 
