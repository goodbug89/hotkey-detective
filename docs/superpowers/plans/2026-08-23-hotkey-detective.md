# HotkeyDetective Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메뉴바에서 "지금 조합을 눌러보세요" → 그 글로벌 단축키를 누가 점유했는지 증거와 함께 판정하는 macOS 앱.

**Architecture:** Swift Package 세 타깃 — `Engine`(순수 로직, `Resolver` → `Evidence` → `VerdictBuilder`), `Probe`(CGEventTap·CGWindowList·Carbon·AX 권한), `HotkeyDetective`(SwiftUI `MenuBarExtra` 실행 타깃). Engine은 Probe를 모르며 픽스처만으로 테스트된다. `.app` 번들은 스크립트로 조립한다.

**Tech Stack:** Swift 5 언어 모드(툴체인 6.x), SwiftUI `MenuBarExtra`, Carbon `RegisterEventHotKey`, CoreGraphics 이벤트 탭, XCTest, `swift build`/`swift test`.

**Spec:** `docs/superpowers/specs/2026-08-23-hotkey-detective-design.md`

## Global Constraints

- 최소 OS: **macOS 14** (`platforms: [.macOS(.v14)]`)
- 샌드박스 없음, `LSUIElement = YES`, Dock 아이콘 없음
- `Engine` 타깃은 `AppKit`/`CoreGraphics` API를 직접 호출하지 않는다 (`Foundation`만 import; Carbon 상수는 정수 리터럴로 정의)
- 이벤트 탭은 반드시 `.listenOnly` — 키를 소비하지 않는다
- Resolver 실패는 빈 배열 + `os_log(.debug)`; 사용자에게 오류를 띄우지 않는다
- `REACTION_DELAY = 0.3s`, `LISTEN_TIMEOUT = 15s` (상수로 분리)
- UI 문자열은 한국어 단일
- 커밋 메시지 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

## 파일 구조

```
Package.swift
Sources/
  Engine/
    KeyCombo.swift            # KeyCombo, Modifiers, 포맷 변환, 글리프
    KeyCodeNames.swift        # keyCode → 표시 문자 테이블 (US 레이아웃)
    Evidence.swift            # Confidence, Owner, Evidence, Verdict
    Resolver.swift            # Resolver 프로토콜, AppIdentity, SystemState, ProbeSnapshot
    VerdictBuilder.swift
    HotKeyRegistrar.swift     # 프로토콜 + RegistrationResult
    Resolvers/
      SystemHotkeyResolver.swift
      SymbolicHotKeyDefaults.swift   # ID→기능명, 기본 조합 테이블
      CarbonOccupancyResolver.swift
      ReactionResolver.swift
      KnownApps/
        KnownAppResolver.swift       # 베이스(파일 로드, 실행 여부, 신뢰도)
        RectangleResolver.swift
        MaccyResolver.swift
        RaycastResolver.swift
  Probe/
    SystemSnapshot.swift
    CarbonHotKeyRegistrar.swift
    AccessibilityGate.swift
    EventTapListener.swift
  HotkeyDetective/
    HotkeyDetectiveApp.swift
    ProbeSession.swift
    Views/PermissionView.swift
    Views/ProbeView.swift
    Views/VerdictView.swift
    Views/ManualComboView.swift
Tests/EngineTests/
  KeyComboTests.swift
  VerdictBuilderTests.swift
  SystemHotkeyResolverTests.swift
  CarbonOccupancyResolverTests.swift
  ReactionResolverTests.swift
  KnownAppResolverTests.swift
  Fixtures/ (symbolichotkeys-*.plist, rectangle.plist, maccy.plist, raycast.plist, broken.plist)
Resources/Info.plist
Scripts/bundle.sh
```

---

### Task 1: 패키지 스캐폴드 + KeyCombo

**Files:**
- Create: `Package.swift`, `.gitignore`
- Create: `Sources/Engine/KeyCombo.swift`, `Sources/Engine/KeyCodeNames.swift`
- Create: `Sources/Probe/Placeholder.swift`, `Sources/HotkeyDetective/main.swift` (빌드 통과용, 이후 교체)
- Test: `Tests/EngineTests/KeyComboTests.swift`

**Interfaces:**
- Produces: `struct KeyCombo { keyCode: UInt16; modifiers: Modifiers; display: String }`, `struct Modifiers: OptionSet` (`.command .shift .option .control .function`), `Modifiers(cgFlags: UInt64)`, `Modifiers(carbon: UInt32)`, `var cgFlags: UInt64`, `var carbon: UInt32`, `KeyCodeNames.name(for: UInt16) -> String`

- [ ] **Step 1: Package.swift 작성**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HotkeyDetective",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Engine"),
        .target(name: "Probe", dependencies: ["Engine"]),
        .executableTarget(name: "HotkeyDetective", dependencies: ["Engine", "Probe"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageVersions: [.v5]
)
```

`.gitignore`:
```
.build/
*.xcodeproj
.DS_Store
build/
```

`Sources/Probe/Placeholder.swift`: `import Foundation` 한 줄. `Sources/HotkeyDetective/main.swift`: `print("placeholder")`. `Tests/EngineTests/Fixtures/.keep` 빈 파일.

- [ ] **Step 2: 실패 테스트 작성**

`Tests/EngineTests/KeyComboTests.swift`:
```swift
import XCTest
@testable import Engine

final class KeyComboTests: XCTestCase {
    func testModifiersFromCGFlags() {
        // ⌘⇧ = command(1<<20) | shift(1<<17)
        let m = Modifiers(cgFlags: (1 << 20) | (1 << 17) | 0x100 /* 무관 비트 */)
        XCTAssertEqual(m, [.command, .shift])
        XCTAssertEqual(m.cgFlags, (1 << 20) | (1 << 17))
    }

    func testModifiersCarbonRoundTrip() {
        let m: Modifiers = [.command, .option, .control, .shift]
        // cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096
        XCTAssertEqual(m.carbon, 256 | 512 | 2048 | 4096)
        XCTAssertEqual(Modifiers(carbon: 256 | 2048), [.command, .option])
    }

    func testDisplayOrderIsControlOptionShiftCommand() {
        let c = KeyCombo(keyCode: 21, modifiers: [.command, .shift])   // 4
        XCTAssertEqual(c.display, "⌘⇧4")
        let all = KeyCombo(keyCode: 0, modifiers: [.shift, .command, .option, .control]) // a
        XCTAssertEqual(all.display, "⌃⌥⇧⌘A")
    }

    func testDisplayOfSpecialKeys() {
        XCTAssertEqual(KeyCombo(keyCode: 49, modifiers: [.option]).display, "⌥Space")
        XCTAssertEqual(KeyCombo(keyCode: 53, modifiers: []).display, "Esc")
        XCTAssertEqual(KeyCombo(keyCode: 111, modifiers: [.function]).display, "fnF12")
        XCTAssertEqual(KeyCombo(keyCode: 999, modifiers: []).display, "Key(999)")
    }

    func testHashableIgnoresNothing() {
        XCTAssertEqual(KeyCombo(keyCode: 1, modifiers: [.command]), KeyCombo(keyCode: 1, modifiers: [.command]))
        XCTAssertNotEqual(KeyCombo(keyCode: 1, modifiers: [.command]), KeyCombo(keyCode: 1, modifiers: [.option]))
    }
}
```

- [ ] **Step 3: 실패 확인**

Run: `swift test --filter KeyComboTests`
Expected: 컴파일 실패 (`KeyCombo` 미정의)

- [ ] **Step 4: 구현**

`Sources/Engine/KeyCombo.swift`:
```swift
import Foundation

public struct Modifiers: OptionSet, Hashable, Codable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control  = Modifiers(rawValue: 1 << 0)
    public static let option   = Modifiers(rawValue: 1 << 1)
    public static let shift    = Modifiers(rawValue: 1 << 2)
    public static let command  = Modifiers(rawValue: 1 << 3)
    public static let function = Modifiers(rawValue: 1 << 4)

    // CGEventFlags / NSEvent.ModifierFlags / symbolichotkeys 마스크 (동일 비트)
    static let cgShift: UInt64 = 1 << 17, cgControl: UInt64 = 1 << 18
    static let cgOption: UInt64 = 1 << 19, cgCommand: UInt64 = 1 << 20, cgFunction: UInt64 = 1 << 23

    // Carbon: cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096
    static let cbCommand: UInt32 = 256, cbShift: UInt32 = 512, cbOption: UInt32 = 2048, cbControl: UInt32 = 4096

    public init(cgFlags: UInt64) {
        var m: Modifiers = []
        if cgFlags & Self.cgControl != 0 { m.insert(.control) }
        if cgFlags & Self.cgOption != 0 { m.insert(.option) }
        if cgFlags & Self.cgShift != 0 { m.insert(.shift) }
        if cgFlags & Self.cgCommand != 0 { m.insert(.command) }
        if cgFlags & Self.cgFunction != 0 { m.insert(.function) }
        self = m
    }

    public var cgFlags: UInt64 {
        var f: UInt64 = 0
        if contains(.control) { f |= Self.cgControl }
        if contains(.option) { f |= Self.cgOption }
        if contains(.shift) { f |= Self.cgShift }
        if contains(.command) { f |= Self.cgCommand }
        if contains(.function) { f |= Self.cgFunction }
        return f
    }

    public init(carbon: UInt32) {
        var m: Modifiers = []
        if carbon & Self.cbControl != 0 { m.insert(.control) }
        if carbon & Self.cbOption != 0 { m.insert(.option) }
        if carbon & Self.cbShift != 0 { m.insert(.shift) }
        if carbon & Self.cbCommand != 0 { m.insert(.command) }
        self = m
    }

    public var carbon: UInt32 {
        var f: UInt32 = 0
        if contains(.control) { f |= Self.cbControl }
        if contains(.option) { f |= Self.cbOption }
        if contains(.shift) { f |= Self.cbShift }
        if contains(.command) { f |= Self.cbCommand }
        return f
    }

    /// 표시 순서: ⌃⌥⇧⌘, fn은 맨 앞
    public var glyphs: String {
        var s = ""
        if contains(.function) { s += "fn" }
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

public struct KeyCombo: Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var display: String { modifiers.glyphs + KeyCodeNames.name(for: keyCode) }
}
```

`Sources/Engine/KeyCodeNames.swift`:
```swift
import Foundation

/// US 레이아웃 기준 keyCode → 표시 이름. v1은 레이아웃 독립 표시 대신 이 테이블을 쓴다.
public enum KeyCodeNames {
    static let table: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "Esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 118: "F4", 120: "F2",
        122: "F1", 115: "Home", 116: "PgUp", 117: "⌦", 119: "End", 121: "PgDn",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt16) -> String {
        table[keyCode] ?? "Key(\(keyCode))"
    }
}
```

- [ ] **Step 5: 통과 확인**

Run: `swift test --filter KeyComboTests`
Expected: 5 tests PASS

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(engine): package scaffold and KeyCombo with CG/Carbon conversions

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Evidence 타입 + Resolver 프로토콜 + VerdictBuilder

**Files:**
- Create: `Sources/Engine/Evidence.swift`, `Sources/Engine/Resolver.swift`, `Sources/Engine/VerdictBuilder.swift`
- Test: `Tests/EngineTests/VerdictBuilderTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`
- Produces:
  - `enum Confidence: Int, Comparable { low, medium, high, certain }`
  - `enum Owner: Hashable { system(feature: String); app(bundleID: String, name: String, action: String?) }`, `var displayName: String`
  - `struct Evidence { source: String; owner: Owner?; confidence: Confidence; rationale: String }`
  - `enum Verdict { confirmed(Owner,[Evidence]); likely(Owner,[Evidence]); contested([Owner],[Evidence]); occupiedUnknown([Evidence]); free([Evidence]) }`, `var evidence: [Evidence]`
  - `struct AppIdentity: Hashable { bundleID: String?; name: String }`
  - `struct SystemState { windows: [pid_t: Set<UInt32>]; frontmostPID: pid_t?; apps: [pid_t: AppIdentity] }`
  - `struct ProbeSnapshot { before: SystemState; after: SystemState; elapsed: TimeInterval; selfPID: pid_t }`
  - `protocol Resolver { var name: String { get }; func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] }`
  - `enum VerdictBuilder { static func build(_ evidence: [Evidence]) -> Verdict }`

- [ ] **Step 1: 실패 테스트 작성**

`Tests/EngineTests/VerdictBuilderTests.swift`:
```swift
import XCTest
@testable import Engine

final class VerdictBuilderTests: XCTestCase {
    let sys = Owner.system(feature: "영역 스크린샷")
    let ray = Owner.app(bundleID: "com.raycast.macos", name: "Raycast", action: nil)
    let rect = Owner.app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "왼쪽 절반")

    func ev(_ owner: Owner?, _ c: Confidence, src: String = "t") -> Evidence {
        Evidence(source: src, owner: owner, confidence: c, rationale: "r")
    }

    func testNoEvidenceIsFree() {
        guard case .free(let e) = VerdictBuilder.build([]) else { return XCTFail() }
        XCTAssertTrue(e.isEmpty)
    }

    func testSingleCertainIsConfirmed() {
        guard case .confirmed(let o, _) = VerdictBuilder.build([ev(sys, .certain)]) else { return XCTFail() }
        XCTAssertEqual(o, sys)
    }

    func testTwoCertainDifferentOwnersIsContested() {
        guard case .contested(let owners, _) = VerdictBuilder.build([ev(sys, .certain), ev(ray, .certain)]) else { return XCTFail() }
        XCTAssertEqual(Set(owners), [sys, ray])
    }

    func testCertainPlusHighSameOwnerStillConfirmed() {
        guard case .confirmed(let o, let e) = VerdictBuilder.build([ev(ray, .high), ev(ray, .certain)]) else { return XCTFail() }
        XCTAssertEqual(o, ray); XCTAssertEqual(e.count, 2)
    }

    func testSingleHighOwnerIsLikely() {
        guard case .likely(let o, _) = VerdictBuilder.build([ev(nil, .high), ev(ray, .high)]) else { return XCTFail() }
        XCTAssertEqual(o, ray)
    }

    func testMediumOnlyIsLikely() {
        guard case .likely(let o, _) = VerdictBuilder.build([ev(ray, .medium)]) else { return XCTFail() }
        XCTAssertEqual(o, ray)
    }

    func testTwoHighOwnersIsContested() {
        guard case .contested(let owners, _) = VerdictBuilder.build([ev(ray, .high), ev(rect, .medium)]) else { return XCTFail() }
        XCTAssertEqual(owners.first, ray, "높은 신뢰도 먼저")
        XCTAssertEqual(owners.count, 2)
    }

    func testOnlyNilOwnerIsOccupiedUnknown() {
        guard case .occupiedUnknown(let e) = VerdictBuilder.build([ev(nil, .high)]) else { return XCTFail() }
        XCTAssertEqual(e.count, 1)
    }

    func testLowOnlyIsFreeButKeepsEvidence() {
        guard case .free(let e) = VerdictBuilder.build([ev(rect, .low)]) else { return XCTFail() }
        XCTAssertEqual(e.count, 1)
    }

    func testOwnerDisplayName() {
        XCTAssertEqual(sys.displayName, "영역 스크린샷 (시스템)")
        XCTAssertEqual(rect.displayName, "Rectangle · 왼쪽 절반")
        XCTAssertEqual(ray.displayName, "Raycast")
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter VerdictBuilderTests` → 컴파일 실패

- [ ] **Step 3: 구현**

`Sources/Engine/Evidence.swift`:
```swift
import Foundation

public enum Confidence: Int, Comparable, Codable {
    case low, medium, high, certain
    public static func < (a: Confidence, b: Confidence) -> Bool { a.rawValue < b.rawValue }
}

public enum Owner: Hashable, Codable {
    case system(feature: String)
    case app(bundleID: String, name: String, action: String?)

    public var displayName: String {
        switch self {
        case .system(let f): return "\(f) (시스템)"
        case .app(_, let name, let action):
            if let a = action { return "\(name) · \(a)" }
            return name
        }
    }
}

public struct Evidence: Hashable, Codable {
    public let source: String
    public let owner: Owner?
    public let confidence: Confidence
    public let rationale: String

    public init(source: String, owner: Owner?, confidence: Confidence, rationale: String) {
        self.source = source; self.owner = owner; self.confidence = confidence; self.rationale = rationale
    }
}

public enum Verdict {
    case confirmed(Owner, [Evidence])
    case likely(Owner, [Evidence])
    case contested([Owner], [Evidence])
    case occupiedUnknown([Evidence])
    case free([Evidence])

    public var evidence: [Evidence] {
        switch self {
        case .confirmed(_, let e), .likely(_, let e), .contested(_, let e), .occupiedUnknown(let e), .free(let e): return e
        }
    }
}
```

`Sources/Engine/Resolver.swift`:
```swift
import Foundation

public struct AppIdentity: Hashable, Codable {
    public let bundleID: String?
    public let name: String
    public init(bundleID: String?, name: String) { self.bundleID = bundleID; self.name = name }
}

public struct SystemState {
    public let windows: [pid_t: Set<UInt32>]
    public let frontmostPID: pid_t?
    public let apps: [pid_t: AppIdentity]
    public init(windows: [pid_t: Set<UInt32>], frontmostPID: pid_t?, apps: [pid_t: AppIdentity]) {
        self.windows = windows; self.frontmostPID = frontmostPID; self.apps = apps
    }
}

public struct ProbeSnapshot {
    public let before: SystemState
    public let after: SystemState
    public let elapsed: TimeInterval
    public let selfPID: pid_t
    public init(before: SystemState, after: SystemState, elapsed: TimeInterval, selfPID: pid_t) {
        self.before = before; self.after = after; self.elapsed = elapsed; self.selfPID = selfPID
    }
}

public protocol Resolver {
    var name: String { get }
    /// probe == nil 이면 제한 모드(권한 없음). 스냅샷이 필요한 Resolver는 빈 배열을 반환한다.
    func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence]
}
```

`Sources/Engine/VerdictBuilder.swift`:
```swift
import Foundation

public enum VerdictBuilder {
    public static func build(_ evidence: [Evidence]) -> Verdict {
        if evidence.isEmpty { return .free([]) }

        let sorted = evidence.sorted { $0.confidence > $1.confidence }

        // 규칙 1: certain
        let certainOwners = uniqueOwners(sorted.filter { $0.confidence == .certain })
        if certainOwners.count == 1 { return .confirmed(certainOwners[0], sorted) }
        if certainOwners.count > 1 { return .contested(certainOwners, sorted) }

        // 규칙 2~3: medium 이상 non-nil owner
        let candidates = uniqueOwners(sorted.filter { $0.confidence >= .medium })
        if candidates.count == 1 { return .likely(candidates[0], sorted) }
        if candidates.count > 1 { return .contested(candidates, sorted) }

        // 규칙 4: owner는 없지만 medium 이상 증거(Carbon 점유 등)
        if sorted.contains(where: { $0.confidence >= .medium }) { return .occupiedUnknown(sorted) }

        // 규칙 5: low만 남음
        return .free(sorted)
    }

    /// 신뢰도 내림차순을 유지하며 owner 중복 제거 (nil 제외)
    private static func uniqueOwners(_ evidence: [Evidence]) -> [Owner] {
        var seen = Set<Owner>(), out: [Owner] = []
        for e in evidence {
            guard let o = e.owner, !seen.contains(o) else { continue }
            seen.insert(o); out.append(o)
        }
        return out
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter VerdictBuilderTests` → 10 PASS

- [ ] **Step 5: 커밋**

```bash
git add -A && git commit -m "feat(engine): evidence types, resolver protocol, verdict builder

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: SystemHotkeyResolver (symbolichotkeys.plist + 기본값)

**Files:**
- Create: `Sources/Engine/Resolvers/SymbolicHotKeyDefaults.swift`, `Sources/Engine/Resolvers/SystemHotkeyResolver.swift`
- Create: `Tests/EngineTests/Fixtures/symbolichotkeys-default.plist`, `symbolichotkeys-disabled28.plist`, `symbolichotkeys-custom28.plist`
- Test: `Tests/EngineTests/SystemHotkeyResolverTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`, `Modifiers(cgFlags:)`, `Evidence`, `Owner.system`, `Resolver`
- Produces: `SystemHotkeyResolver(plistURL: URL)` (기본값: `~/Library/Preferences/com.apple.symbolichotkeys.plist`), `SymbolicHotKeyDefaults.entries: [Int: (feature: String, combo: KeyCombo?)]`

**plist 구조 (실측):** `AppleSymbolicHotKeys` → `"28"` → `{enabled: Bool, value: {parameters: [ascii, keyCode, modifierMask], type: "standard"}}`. 항목이 **없으면 기본값**이 적용된 상태다. `value`가 없는 항목(`enabled`만 있음)은 기본 조합을 유지한 채 on/off만 바뀐 것이다.

- [ ] **Step 1: 픽스처 작성**

`Tests/EngineTests/Fixtures/symbolichotkeys-default.plist` (28 항목 없음 → 기본 ⌘⇧4):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>AppleSymbolicHotKeys</key><dict>
    <key>15</key><dict><key>enabled</key><false/></dict>
    <key>64</key><dict><key>enabled</key><true/>
      <key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>
  </dict>
</dict></plist>
```

`symbolichotkeys-disabled28.plist`: 위와 동일하되 `<key>28</key><dict><key>enabled</key><false/></dict>` 추가.

`symbolichotkeys-custom28.plist`: 위와 동일하되
```xml
<key>28</key><dict><key>enabled</key><true/>
  <key>value</key><dict><key>parameters</key><array><integer>53</integer><integer>23</integer><integer>1572864</integer></array><key>type</key><string>standard</string></dict></dict>
```
(→ ⌥⌘5: keyCode 23, mask = option(1<<19)|command(1<<20) = 1572864)

- [ ] **Step 2: 실패 테스트 작성**

`Tests/EngineTests/SystemHotkeyResolverTests.swift`:
```swift
import XCTest
@testable import Engine

final class SystemHotkeyResolverTests: XCTestCase {
    func fixture(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "plist", subdirectory: "Fixtures")!
    }
    let cmdShift4 = KeyCombo(keyCode: 21, modifiers: [.command, .shift])

    func testDefaultScreenshotWhenEntryAbsent() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        let e = r.resolve(cmdShift4, probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .system(feature: "영역 스크린샷"))
        XCTAssertEqual(e[0].confidence, .certain)
    }

    func testDisabledEntryGivesNothing() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-disabled28"))
        XCTAssertTrue(r.resolve(cmdShift4, probe: nil).isEmpty)
    }

    func testCustomEntryOverridesDefault() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-custom28"))
        XCTAssertTrue(r.resolve(cmdShift4, probe: nil).isEmpty)
        let e = r.resolve(KeyCombo(keyCode: 23, modifiers: [.command, .option]), probe: nil)
        XCTAssertEqual(e.first?.owner, .system(feature: "영역 스크린샷"))
    }

    func testExplicitlyEnabledEntryFromPlist() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        let e = r.resolve(KeyCombo(keyCode: 49, modifiers: [.command]), probe: nil)
        XCTAssertEqual(e.first?.owner, .system(feature: "Spotlight 검색"))
    }

    func testMissingFileFallsBackToDefaults() {
        let r = SystemHotkeyResolver(plistURL: URL(fileURLWithPath: "/nonexistent.plist"))
        XCTAssertEqual(r.resolve(cmdShift4, probe: nil).first?.owner, .system(feature: "영역 스크린샷"))
    }

    func testUnknownIDUsesGenericName() {
        // custom28 픽스처에 없는 ID 999를 enabled로 넣은 임시 plist
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("shk-\(UUID()).plist")
        let dict: [String: Any] = ["AppleSymbolicHotKeys": ["999": ["enabled": true,
            "value": ["parameters": [65535, 111, 8388608], "type": "standard"]]]]
        try! PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: tmp)
        let r = SystemHotkeyResolver(plistURL: tmp)
        let e = r.resolve(KeyCombo(keyCode: 111, modifiers: [.function]), probe: nil)
        XCTAssertEqual(e.first?.owner, .system(feature: "시스템 기능 #999"))
    }
}
```

- [ ] **Step 3: 실패 확인**

Run: `swift test --filter SystemHotkeyResolverTests` → 컴파일 실패

- [ ] **Step 4: 구현**

`Sources/Engine/Resolvers/SymbolicHotKeyDefaults.swift`:
```swift
import Foundation

/// symbolichotkeys ID → (기능명, 기본 조합). 기본 조합이 nil이면 기본적으로 비활성.
/// 출처: macOS 시스템 설정 > 키보드 > 단축키 기본값. ID는 Apple 비공개 상수로 안정적.
public enum SymbolicHotKeyDefaults {
    static func c(_ k: UInt16, _ m: Modifiers) -> KeyCombo { KeyCombo(keyCode: k, modifiers: m) }

    public static let entries: [Int: (feature: String, combo: KeyCombo?)] = [
        7: ("Dock 가리기/보기", c(2, [.command, .option])),
        15: ("화면 확대/축소 전환", c(28, [.command, .option])),
        17: ("확대", c(24, [.command, .option])),
        19: ("축소", c(27, [.command, .option])),
        21: ("색상 반전", c(8, [.command, .option, .control])),
        25: ("대비 높이기", c(47, [.command, .option, .control])),
        26: ("대비 낮추기", c(43, [.command, .option, .control])),
        27: ("다음 윈도우로 이동", c(50, [.command])),
        28: ("전체 화면 스크린샷 저장", c(20, [.command, .shift])),      // ⌘⇧3
        29: ("전체 화면 스크린샷 클립보드", c(20, [.command, .shift, .control])),
        30: ("영역 스크린샷", c(21, [.command, .shift])),                 // ⌘⇧4
        31: ("영역 스크린샷 클립보드", c(21, [.command, .shift, .control])),
        32: ("Mission Control", c(126, [.control])),
        33: ("응용 프로그램 윈도우", c(125, [.control])),
        34: ("Mission Control (마우스)", nil),
        36: ("데스크탑 보기", c(103, [])),                                   // F11
        52: ("Dock 포커스", c(3, [.control])),
        57: ("키보드 초점 이동 전환", c(111, [.control])),                 // ^F7
        59: ("메뉴 막대 이동", c(120, [.control])),                         // ^F2
        60: ("이전 입력 소스 선택", c(49, [.control])),                     // ^Space
        61: ("입력 메뉴의 다음 소스 선택", c(49, [.control, .option])),
        64: ("Spotlight 검색", c(49, [.command])),                          // ⌘Space
        65: ("Finder 검색 윈도우", c(49, [.command, .option])),
        79: ("왼쪽 Space로 이동", c(123, [.control])),
        81: ("오른쪽 Space로 이동", c(124, [.control])),
        118: ("데스크탑 1로 전환", c(18, [.control])),
        119: ("데스크탑 2로 전환", c(19, [.control])),
        120: ("데스크탑 3로 전환", c(20, [.control])),
        121: ("데스크탑 4로 전환", c(21, [.control])),
        160: ("Launchpad 보기", nil),
        163: ("알림 센터 보기", nil),
        164: ("방해금지 모드 전환", nil),
        175: ("손쉬운 사용 단축키", c(96, [.command, .option])),           // ⌥⌘F5
        184: ("스크린샷 및 화면 기록 옵션", c(23, [.command, .shift])),   // ⌘⇧5
    ]

    public static func feature(for id: Int) -> String {
        entries[id]?.feature ?? "시스템 기능 #\(id)"
    }
}
```

> 주의: 이 테이블은 전수 검증 대상(스펙 13절)이며, 틀린 항목은 `certain` 오판을 낳으므로 구현 시 `defaults read com.apple.symbolichotkeys`와 시스템 설정 화면을 대조한다.

`Sources/Engine/Resolvers/SystemHotkeyResolver.swift`:
```swift
import Foundation

public struct SystemHotkeyResolver: Resolver {
    public let name = "시스템 단축키"
    let plistURL: URL

    public init(plistURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")) {
        self.plistURL = plistURL
    }

    struct Entry { let id: Int; let enabled: Bool; let combo: KeyCombo? }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        effectiveEntries().compactMap { e in
            guard e.enabled, e.combo == combo else { return nil }
            return Evidence(source: name, owner: .system(feature: SymbolicHotKeyDefaults.feature(for: e.id)),
                            confidence: .certain,
                            rationale: "symbolichotkeys 항목 \(e.id)이(가) \(combo.display)으로 활성화됨")
        }
    }

    /// 기본값 테이블 위에 plist 내용을 덮어쓴 최종 상태
    func effectiveEntries() -> [Entry] {
        var map: [Int: Entry] = [:]
        for (id, d) in SymbolicHotKeyDefaults.entries {
            map[id] = Entry(id: id, enabled: d.combo != nil, combo: d.combo)
        }
        for (id, raw) in loadPlist() {
            let enabled = raw["enabled"] as? Bool ?? true
            var combo = map[id]?.combo
            if let value = raw["value"] as? [String: Any],
               let p = value["parameters"] as? [Any], p.count == 3,
               let key = (p[1] as? NSNumber)?.uint16Value, let mask = (p[2] as? NSNumber)?.uint64Value,
               key != 65535 {
                combo = KeyCombo(keyCode: key, modifiers: Modifiers(cgFlags: mask))
            }
            map[id] = Entry(id: id, enabled: enabled, combo: combo)
        }
        return Array(map.values)
    }

    private func loadPlist() -> [Int: [String: Any]] {
        guard let data = try? Data(contentsOf: plistURL),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let hot = root["AppleSymbolicHotKeys"] as? [String: [String: Any]] else { return [:] }
        var out: [Int: [String: Any]] = [:]
        for (k, v) in hot { if let id = Int(k) { out[id] = v } }
        return out
    }
}
```

- [ ] **Step 5: 통과 확인**

Run: `swift test --filter SystemHotkeyResolverTests` → 6 PASS

- [ ] **Step 6: 기본값 테이블 실기 대조**

Run: `defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys | grep -B1 -A8 '"28"\|"30"\|"64"'`
시스템 설정 > 키보드 > 키보드 단축키 화면과 대조해 28/29/30/31/64/32/60/175/184의 조합이 테이블과 일치하는지 확인. 불일치 시 테이블 수정.

- [ ] **Step 7: 커밋**

```bash
git add -A && git commit -m "feat(engine): system hotkey resolver with symbolichotkeys defaults

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: CarbonOccupancyResolver + HotKeyRegistrar 프로토콜

**Files:**
- Create: `Sources/Engine/HotKeyRegistrar.swift`, `Sources/Engine/Resolvers/CarbonOccupancyResolver.swift`
- Test: `Tests/EngineTests/CarbonOccupancyResolverTests.swift`

**Interfaces:**
- Produces: `enum RegistrationResult { registeredAndReleased, occupied, error(Int32) }`, `protocol HotKeyRegistrar { func tryRegister(_ combo: KeyCombo) -> RegistrationResult }`, `CarbonOccupancyResolver(registrar: HotKeyRegistrar)`

- [ ] **Step 1: 실패 테스트 작성**

```swift
import XCTest
@testable import Engine

final class CarbonOccupancyResolverTests: XCTestCase {
    struct Fake: HotKeyRegistrar {
        let result: RegistrationResult
        func tryRegister(_ combo: KeyCombo) -> RegistrationResult { result }
    }
    let combo = KeyCombo(keyCode: 49, modifiers: [.option])

    func testOccupiedYieldsHighEvidenceWithNilOwner() {
        let e = CarbonOccupancyResolver(registrar: Fake(result: .occupied)).resolve(combo, probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertNil(e[0].owner)
        XCTAssertEqual(e[0].confidence, .high)
    }

    func testFreeYieldsNothing() {
        XCTAssertTrue(CarbonOccupancyResolver(registrar: Fake(result: .registeredAndReleased)).resolve(combo, probe: nil).isEmpty)
    }

    func testErrorYieldsNothing() {
        XCTAssertTrue(CarbonOccupancyResolver(registrar: Fake(result: .error(-50))).resolve(combo, probe: nil).isEmpty)
    }
}
```

- [ ] **Step 2: 실패 확인** — `swift test --filter CarbonOccupancyResolverTests` → 컴파일 실패

- [ ] **Step 3: 구현**

`Sources/Engine/HotKeyRegistrar.swift`:
```swift
import Foundation

public enum RegistrationResult: Equatable {
    case registeredAndReleased
    case occupied          // eventHotKeyExistsErr (-9878)
    case error(Int32)
}

public protocol HotKeyRegistrar {
    func tryRegister(_ combo: KeyCombo) -> RegistrationResult
}
```

`Sources/Engine/Resolvers/CarbonOccupancyResolver.swift`:
```swift
import Foundation
import os

public struct CarbonOccupancyResolver: Resolver {
    public let name = "핫키 등록 시도"
    let registrar: HotKeyRegistrar
    private static let log = Logger(subsystem: "HotkeyDetective", category: "carbon")

    public init(registrar: HotKeyRegistrar) { self.registrar = registrar }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        switch registrar.tryRegister(combo) {
        case .occupied:
            return [Evidence(source: name, owner: nil, confidence: .high,
                             rationale: "다른 프로세스가 \(combo.display)을(를) Carbon 핫키로 등록함")]
        case .registeredAndReleased:
            return []
        case .error(let code):
            Self.log.debug("RegisterEventHotKey error \(code)")
            return []
        }
    }
}
```

- [ ] **Step 4: 통과 확인** — 3 PASS

- [ ] **Step 5: 커밋**

```bash
git add -A && git commit -m "feat(engine): carbon occupancy resolver behind HotKeyRegistrar protocol

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: ReactionResolver

**Files:**
- Create: `Sources/Engine/Resolvers/ReactionResolver.swift`
- Test: `Tests/EngineTests/ReactionResolverTests.swift`

**Interfaces:**
- Consumes: `ProbeSnapshot`, `SystemState`, `AppIdentity`
- Produces: `ReactionResolver()`, `ReactionResolver.excludedBundleIDs: Set<String>`

- [ ] **Step 1: 실패 테스트 작성**

```swift
import XCTest
@testable import Engine

final class ReactionResolverTests: XCTestCase {
    let combo = KeyCombo(keyCode: 49, modifiers: [.option])
    let me: pid_t = 100, ray: pid_t = 200, rect: pid_t = 300, dock: pid_t = 400
    var apps: [pid_t: AppIdentity] {
        [me: .init(bundleID: "dev.goodbug.HotkeyDetective", name: "HotkeyDetective"),
         ray: .init(bundleID: "com.raycast.macos", name: "Raycast"),
         rect: .init(bundleID: "com.knollsoft.Rectangle", name: "Rectangle"),
         dock: .init(bundleID: "com.apple.dock", name: "Dock")]
    }
    func snap(before: [pid_t: Set<UInt32>], after: [pid_t: Set<UInt32>], frontBefore: pid_t? = nil, frontAfter: pid_t? = nil) -> ProbeSnapshot {
        ProbeSnapshot(before: SystemState(windows: before, frontmostPID: frontBefore, apps: apps),
                      after: SystemState(windows: after, frontmostPID: frontAfter, apps: apps),
                      elapsed: 0.3, selfPID: me)
    }
    let r = ReactionResolver()

    func testNilProbeGivesNothing() {
        XCTAssertTrue(r.resolve(combo, probe: nil).isEmpty)
    }

    func testNewWindowFromOneAppIsHigh() {
        let e = r.resolve(combo, probe: snap(before: [ray: []], after: [ray: [1]]))
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .app(bundleID: "com.raycast.macos", name: "Raycast", action: nil))
        XCTAssertEqual(e[0].confidence, .high)
    }

    func testFrontmostChangeIsHigh() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [:], frontBefore: me, frontAfter: rect))
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: nil))
        XCTAssertEqual(e.first?.confidence, .high)
    }

    func testNoChangeGivesNothing() {
        XCTAssertTrue(r.resolve(combo, probe: snap(before: [ray: [1]], after: [ray: [1]], frontBefore: me, frontAfter: me)).isEmpty)
    }

    func testSelfAndSystemProcessesExcluded() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [me: [5], dock: [6]], frontBefore: nil, frontAfter: dock))
        XCTAssertTrue(e.isEmpty)
    }

    func testTwoReactingAppsAreMediumEach() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [ray: [1], rect: [2]]))
        XCTAssertEqual(e.count, 2)
        XCTAssertTrue(e.allSatisfy { $0.confidence == .medium })
    }

    func testSameAppNewWindowAndFrontmostIsOneEvidence() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [ray: [1]], frontBefore: me, frontAfter: ray))
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].confidence, .high)
    }
}
```

- [ ] **Step 2: 실패 확인** — 컴파일 실패

- [ ] **Step 3: 구현**

```swift
import Foundation

public struct ReactionResolver: Resolver {
    public let name = "반응 감지"
    public static let excludedBundleIDs: Set<String> = [
        "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.loginwindow", "com.apple.WindowManager",
    ]
    public init() {}

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        guard let p = probe else { return [] }
        var reasons: [pid_t: [String]] = [:]

        for (pid, afterWins) in p.after.windows {
            let newWins = afterWins.subtracting(p.before.windows[pid] ?? [])
            if !newWins.isEmpty { reasons[pid, default: []].append("새 창 \(newWins.count)개 표시") }
        }
        if let f = p.after.frontmostPID, f != p.before.frontmostPID {
            reasons[f, default: []].append("활성 앱으로 전환됨")
        }

        let reacting = reasons.keys.filter { !isExcluded($0, p) }.sorted()
        let confidence: Confidence = reacting.count == 1 ? .high : .medium

        return reacting.compactMap { pid in
            guard let app = p.after.apps[pid] else { return nil }
            return Evidence(source: name,
                            owner: .app(bundleID: app.bundleID ?? "pid:\(pid)", name: app.name, action: nil),
                            confidence: confidence,
                            rationale: "\(combo.display) 입력 \(Int(p.elapsed * 1000))ms 후 \(app.name)이(가) " + reasons[pid]!.joined(separator: ", "))
        }
    }

    private func isExcluded(_ pid: pid_t, _ p: ProbeSnapshot) -> Bool {
        if pid == p.selfPID { return true }
        guard let bid = p.after.apps[pid]?.bundleID else { return false }
        return Self.excludedBundleIDs.contains(bid)
    }
}
```

- [ ] **Step 4: 통과 확인** — 7 PASS

- [ ] **Step 5: 커밋**

```bash
git add -A && git commit -m "feat(engine): reaction resolver from window/frontmost diff

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: KnownAppResolver 베이스 + Rectangle/Maccy/Raycast

**Files:**
- Create: `Sources/Engine/Resolvers/KnownApps/KnownAppResolver.swift`, `RectangleResolver.swift`, `MaccyResolver.swift`, `RaycastResolver.swift`
- Create: `Tests/EngineTests/Fixtures/rectangle.plist`, `maccy.plist`, `raycast.plist`, `broken.plist`
- Test: `Tests/EngineTests/KnownAppResolverTests.swift`

**Interfaces:**
- Produces:
  - `protocol RunningAppChecker { func isRunning(bundleID: String) -> Bool }`
  - `struct KnownAppResolver: Resolver` — `init(descriptor: KnownAppDescriptor, fileURL: URL?, running: RunningAppChecker)`
  - `struct KnownAppDescriptor { bundleID: String; name: String; defaultFileURL: URL; parse: ([String: Any]) -> [(action: String, combo: KeyCombo)] }`
  - `KnownApps.rectangle`, `KnownApps.maccy`, `KnownApps.raycast` (descriptor 상수)
  - `KnownApps.all(running:) -> [Resolver]`

**포맷 (검증 필요 — 스펙 13절):**
- Rectangle: 최상위 키가 액션명(`leftHalf`, `rightHalf`, `maximize`, …), 값 `{keyCode: Int, modifierFlags: Int}`; `modifierFlags`는 NSEvent 비트(CG와 동일).
- Maccy: `KeyboardShortcuts_popup` 키에 JSON 문자열 `{"carbonKeyCode":9,"carbonModifiers":4352}` (KeyboardShortcuts 라이브러리 포맷, Carbon 비트).
- Raycast: `raycastGlobalHotkey` 키에 문자열. 알려진 형태 `"Command-49"` (수정자명을 `-`로 연결 후 keyCode). 실제 파일로 확인 전까지 이 파서는 `Command|Option|Control|Shift` 토큰 + 끝 정수만 받아들이고 그 외는 빈 배열.

- [ ] **Step 1: 픽스처 작성**

`rectangle.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>leftHalf</key><dict><key>keyCode</key><integer>123</integer><key>modifierFlags</key><integer>786432</integer></dict>
  <key>rightHalf</key><dict><key>keyCode</key><integer>124</integer><key>modifierFlags</key><integer>786432</integer></dict>
  <key>launchOnLogin</key><true/>
</dict></plist>
```
(786432 = control(1<<18)|option(1<<19) → ⌃⌥←)

`maccy.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>KeyboardShortcuts_popup</key><string>{"carbonKeyCode":9,"carbonModifiers":768}</string>
  <key>pasteByDefault</key><true/>
</dict></plist>
```
(768 = cmdKey 256 | shiftKey 512 → ⌘⇧V)

`raycast.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>raycastGlobalHotkey</key><string>Option-49</string>
</dict></plist>
```

`broken.plist`: 내용 `this is not a plist`.

- [ ] **Step 2: 실패 테스트 작성**

```swift
import XCTest
@testable import Engine

final class KnownAppResolverTests: XCTestCase {
    struct Running: RunningAppChecker {
        let ids: Set<String>
        func isRunning(bundleID: String) -> Bool { ids.contains(bundleID) }
    }
    func fixture(_ n: String) -> URL { Bundle.module.url(forResource: n, withExtension: "plist", subdirectory: "Fixtures")! }

    func testRectangleRunningIsHighWithAction() {
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: ["com.knollsoft.Rectangle"]))
        let e = r.resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "leftHalf"))
        XCTAssertEqual(e[0].confidence, .high)
    }

    func testRectangleNotRunningIsLow() {
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: []))
        let e = r.resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil)
        XCTAssertEqual(e.first?.confidence, .low)
        XCTAssertTrue(e.first!.rationale.contains("실행 중 아님"))
    }

    func testMaccyCarbonFormat() {
        let r = KnownAppResolver(descriptor: KnownApps.maccy, fileURL: fixture("maccy"), running: Running(ids: ["org.p0deje.Maccy"]))
        let e = r.resolve(KeyCombo(keyCode: 9, modifiers: [.command, .shift]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"))
    }

    func testRaycastStringFormat() {
        let r = KnownAppResolver(descriptor: KnownApps.raycast, fileURL: fixture("raycast"), running: Running(ids: ["com.raycast.macos"]))
        let e = r.resolve(KeyCombo(keyCode: 49, modifiers: [.option]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.raycast.macos", name: "Raycast", action: "호출"))
    }

    func testNonMatchingComboGivesNothing() {
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: []))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 0, modifiers: [.command]), probe: nil).isEmpty)
    }

    func testBrokenAndMissingFilesGiveNothing() {
        XCTAssertTrue(KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("broken"), running: Running(ids: [])).resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil).isEmpty)
        XCTAssertTrue(KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: URL(fileURLWithPath: "/nope.plist"), running: Running(ids: [])).resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil).isEmpty)
    }

    func testAllBuildsThreeResolvers() {
        XCTAssertEqual(KnownApps.all(running: Running(ids: [])).count, 3)
    }
}
```

- [ ] **Step 3: 실패 확인** — 컴파일 실패

- [ ] **Step 4: 구현**

`KnownAppResolver.swift`:
```swift
import Foundation
import os

public protocol RunningAppChecker {
    func isRunning(bundleID: String) -> Bool
}

public struct KnownAppDescriptor {
    public let bundleID: String
    public let name: String
    public let defaultFileURL: URL
    /// plist 루트 딕셔너리 → (액션명, 조합) 목록
    public let parse: ([String: Any]) -> [(action: String, combo: KeyCombo)]
}

public struct KnownAppResolver: Resolver {
    public var name: String { "\(descriptor.name) 설정" }
    let descriptor: KnownAppDescriptor
    let fileURL: URL
    let running: RunningAppChecker
    private static let log = Logger(subsystem: "HotkeyDetective", category: "knownapp")

    public init(descriptor: KnownAppDescriptor, fileURL: URL? = nil, running: RunningAppChecker) {
        self.descriptor = descriptor
        self.fileURL = fileURL ?? descriptor.defaultFileURL
        self.running = running
    }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        guard let data = try? Data(contentsOf: fileURL),
              let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            Self.log.debug("\(descriptor.name): 설정 파일 없음/파싱 실패 \(fileURL.path)")
            return []
        }
        let isRunning = running.isRunning(bundleID: descriptor.bundleID)
        return descriptor.parse(root).filter { $0.combo == combo }.map { hit in
            Evidence(source: name,
                     owner: .app(bundleID: descriptor.bundleID, name: descriptor.name, action: hit.action),
                     confidence: isRunning ? .high : .low,
                     rationale: isRunning
                        ? "\(descriptor.name) 설정 파일에 '\(hit.action)' = \(combo.display)"
                        : "\(descriptor.name) 설정에 '\(hit.action)' = \(combo.display) — 현재 실행 중 아님, 실행 시 충돌 예상")
        }
    }
}

public enum KnownApps {
    static let prefs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")

    public static func all(running: RunningAppChecker) -> [Resolver] {
        [rectangle, maccy, raycast].map { KnownAppResolver(descriptor: $0, running: running) }
    }
}
```

`RectangleResolver.swift`:
```swift
import Foundation

extension KnownApps {
    public static let rectangle = KnownAppDescriptor(
        bundleID: "com.knollsoft.Rectangle", name: "Rectangle",
        defaultFileURL: prefs.appendingPathComponent("com.knollsoft.Rectangle.plist")
    ) { root in
        root.compactMap { key, value in
            guard let d = value as? [String: Any],
                  let k = (d["keyCode"] as? NSNumber)?.uint16Value,
                  let m = (d["modifierFlags"] as? NSNumber)?.uint64Value else { return nil }
            return (action: key, combo: KeyCombo(keyCode: k, modifiers: Modifiers(cgFlags: m)))
        }
    }
}
```

`MaccyResolver.swift`:
```swift
import Foundation

extension KnownApps {
    public static let maccy = KnownAppDescriptor(
        bundleID: "org.p0deje.Maccy", name: "Maccy",
        defaultFileURL: prefs.appendingPathComponent("org.p0deje.Maccy.plist")
    ) { root in
        root.compactMap { key, value in
            guard key.hasPrefix("KeyboardShortcuts_"), let s = value as? String,
                  let data = s.data(using: .utf8),
                  let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let k = (j["carbonKeyCode"] as? NSNumber)?.uint16Value,
                  let m = (j["carbonModifiers"] as? NSNumber)?.uint32Value else { return nil }
            return (action: String(key.dropFirst("KeyboardShortcuts_".count)),
                    combo: KeyCombo(keyCode: k, modifiers: Modifiers(carbon: m)))
        }
    }
}
```

`RaycastResolver.swift`:
```swift
import Foundation

extension KnownApps {
    /// 형식 "Command-Shift-49": 수정자 토큰들 + 마지막 정수 keyCode. 확인 전 가정 — 스펙 13절.
    public static let raycast = KnownAppDescriptor(
        bundleID: "com.raycast.macos", name: "Raycast",
        defaultFileURL: prefs.appendingPathComponent("com.raycast.macos.plist")
    ) { root in
        guard let s = root["raycastGlobalHotkey"] as? String, let combo = parseRaycast(s) else { return [] }
        return [(action: "호출", combo: combo)]
    }

    static func parseRaycast(_ s: String) -> KeyCombo? {
        var parts = s.split(separator: "-").map(String.init)
        guard let last = parts.popLast(), let key = UInt16(last) else { return nil }
        var m: Modifiers = []
        for p in parts {
            switch p {
            case "Command": m.insert(.command)
            case "Shift": m.insert(.shift)
            case "Option": m.insert(.option)
            case "Control": m.insert(.control)
            default: return nil
            }
        }
        return KeyCombo(keyCode: key, modifiers: m)
    }
}
```

- [ ] **Step 5: 통과 확인** — `swift test` 전체 → 전부 PASS

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(engine): known-app resolvers for Rectangle, Maccy, Raycast

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Probe — SystemSnapshot, CarbonHotKeyRegistrar, AccessibilityGate, RunningApps

**Files:**
- Delete: `Sources/Probe/Placeholder.swift`
- Create: `Sources/Probe/SystemSnapshot.swift`, `Sources/Probe/CarbonHotKeyRegistrar.swift`, `Sources/Probe/AccessibilityGate.swift`, `Sources/Probe/WorkspaceRunningApps.swift`

**Interfaces:**
- Consumes: `SystemState`, `AppIdentity`, `HotKeyRegistrar`, `RegistrationResult`, `RunningAppChecker`
- Produces: `SystemSnapshot.capture() -> SystemState`, `CarbonHotKeyRegistrar()`, `AccessibilityGate.isTrusted(prompt: Bool) -> Bool`, `AccessibilityGate.openSettings()`, `WorkspaceRunningApps()`

테스트: 이 계층은 권한이 필요해 단위 테스트 없음. Step 5의 수동 검증으로 대체.

- [ ] **Step 1: SystemSnapshot**

```swift
import AppKit
import CoreGraphics
import Engine

public enum SystemSnapshot {
    public static func capture() -> SystemState {
        var windows: [pid_t: Set<UInt32>] = [:]
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard let pid = (w[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                      let wid = (w[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                      let layer = (w[kCGWindowLayer as String] as? NSNumber)?.intValue,
                      layer >= 0 else { continue }
                windows[pid, default: []].insert(wid)
            }
        }
        var apps: [pid_t: AppIdentity] = [:]
        for a in NSWorkspace.shared.runningApplications {
            apps[a.processIdentifier] = AppIdentity(bundleID: a.bundleIdentifier, name: a.localizedName ?? "pid \(a.processIdentifier)")
        }
        return SystemState(windows: windows,
                           frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                           apps: apps)
    }
}
```

- [ ] **Step 2: CarbonHotKeyRegistrar**

```swift
import Carbon
import Engine

public struct CarbonHotKeyRegistrar: HotKeyRegistrar {
    public init() {}

    public func tryRegister(_ combo: KeyCombo) -> RegistrationResult {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x48444554) /* 'HDET' */, id: 1)
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.carbon, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            if let r = ref { UnregisterEventHotKey(r) }
            return .registeredAndReleased
        }
        if status == OSStatus(eventHotKeyExistsErr) { return .occupied }   // -9878
        return .error(status)
    }
}
```

- [ ] **Step 3: AccessibilityGate + WorkspaceRunningApps**

`AccessibilityGate.swift`:
```swift
import AppKit
import ApplicationServices

public enum AccessibilityGate {
    public static func isTrusted(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    public static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

`WorkspaceRunningApps.swift`:
```swift
import AppKit
import Engine

public struct WorkspaceRunningApps: RunningAppChecker {
    public init() {}
    public func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}
```

- [ ] **Step 4: 빌드 확인**

Run: `rm Sources/Probe/Placeholder.swift && swift build`
Expected: 성공 (경고 가능)

- [ ] **Step 5: Carbon 점유 실기 검증 (임시 main.swift)**

`Sources/HotkeyDetective/main.swift`를 임시로:
```swift
import Engine
import Probe
let r = CarbonHotKeyRegistrar()
print("⌘⇧4:", r.tryRegister(KeyCombo(keyCode: 21, modifiers: [.command, .shift])))
print("⌃⌥⌘F12:", r.tryRegister(KeyCombo(keyCode: 111, modifiers: [.command, .option, .control])))
```
Run: `swift run HotkeyDetective`
Expected: 첫 줄은 시스템 스크린샷 때문에 `occupied`일 수도, `registeredAndReleased`일 수도 있다(시스템 단축키는 Carbon 핫키 테이블을 안 거칠 수 있음). **결과를 스펙 13절에 기록.** 둘째 줄은 `registeredAndReleased`여야 함. 아니면 Carbon 호출부를 점검.

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(probe): system snapshot, carbon registrar, accessibility gate

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Probe — EventTapListener

**Files:**
- Create: `Sources/Probe/EventTapListener.swift`

**Interfaces:**
- Produces:
  ```swift
  public final class EventTapListener {
      public enum Outcome { case combo(KeyCombo), cancelled, timedOut, tapFailed }
      public init(timeout: TimeInterval = 15)
      public func start(_ handler: @escaping (Outcome) -> Void)   // 메인 스레드에서 콜백
      public func stop()
  }
  ```

동작: `.cgSessionEventTap`, `.headInsertEventTap`, `.listenOnly`, keyDown만. 수정자 없는 키(단, 수정자 키 자체 keyDown은 오지 않음)는 무시. keyCode 53(Esc)는 `cancelled`. 첫 유효 조합에서 즉시 `stop()` 후 `combo`. `tapDisabledByTimeout/UserInput` 수신 시 재활성화. 생성 실패 → `tapFailed`.

- [ ] **Step 1: 구현**

```swift
import CoreGraphics
import Foundation
import Engine

public final class EventTapListener {
    public enum Outcome { case combo(KeyCombo), cancelled, timedOut, tapFailed }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timeoutTimer: Timer?
    private var handler: ((Outcome) -> Void)?
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 15) { self.timeout = timeout }

    public func start(_ handler: @escaping (Outcome) -> Void) {
        stop()
        self.handler = handler
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .listenOnly, eventsOfInterest: CGEventMask(mask),
                                          callback: { _, type, event, refcon in
                                              let me = Unmanaged<EventTapListener>.fromOpaque(refcon!).takeUnretainedValue()
                                              me.handle(type: type, event: event)
                                              return Unmanaged.passUnretained(event)
                                          }, userInfo: selfPtr) else {
            finish(.tapFailed); return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.finish(.timedOut)
        }
    }

    public func stop() {
        timeoutTimer?.invalidate(); timeoutTimer = nil
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        tap = nil; source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 53 { finish(.cancelled); return }
            let mods = Modifiers(cgFlags: event.flags.rawValue).subtracting(.function)
            guard !mods.isEmpty else { return }
            let full = Modifiers(cgFlags: event.flags.rawValue)
            finish(.combo(KeyCombo(keyCode: keyCode, modifiers: full)))
        default: break
        }
    }

    private func finish(_ outcome: Outcome) {
        let h = handler
        handler = nil
        stop()
        DispatchQueue.main.async { h?(outcome) }
    }
}
```

> `fn`만 누른 조합(예: fn+F12)은 의도적으로 무시하지 않도록 `subtracting(.function)` 후 비어 있으면 무시 — 즉 fn 단독은 수정자로 치지 않는다. fn+다른 수정자는 통과.

- [ ] **Step 2: 실기 검증 (임시 main.swift)**

```swift
import AppKit
import Engine
import Probe
let app = NSApplication.shared
print("trusted:", AccessibilityGate.isTrusted(prompt: true))
let before = SystemSnapshot.capture()
let l = EventTapListener()
print("지금 조합을 누르세요 (15초)")
l.start { outcome in
    guard case .combo(let c) = outcome else { print(outcome); exit(0) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        let after = SystemSnapshot.capture()
        let probe = ProbeSnapshot(before: before, after: after, elapsed: 0.3, selfPID: getpid())
        let resolvers: [Resolver] = [SystemHotkeyResolver(), CarbonOccupancyResolver(registrar: CarbonHotKeyRegistrar()),
                                     ReactionResolver()] + KnownApps.all(running: WorkspaceRunningApps())
        let ev = resolvers.flatMap { $0.resolve(c, probe: probe) }
        print(c.display, VerdictBuilder.build(ev))
        exit(0)
    }
}
app.run()
```
Run: `swift build && .build/debug/HotkeyDetective` (터미널 앱에 손쉬운 사용 권한 필요 — 시스템 설정에서 터미널 허용)
- ⌘⇧4 → `confirmed(system(영역 스크린샷))` 확인. **이게 실패하면 `.cgSessionEventTap`이 시스템 핫키 이벤트를 못 받는 것** → `.cgHIDEventTap`으로 바꿔 재시도, 결과를 스펙 13절에 기록.
- ⌃⌥⌘F12 → `free`.
- 300ms 안에 Spotlight(⌘Space) 창이 `ReactionResolver`에 잡히는지 확인. 안 잡히면 `REACTION_DELAY`를 500ms로 올리고 기록.

- [ ] **Step 3: 커밋**

```bash
git add -A && git commit -m "feat(probe): listen-only event tap listener with timeout and cancel

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: ProbeSession 상태 머신

**Files:**
- Delete: `Sources/HotkeyDetective/main.swift`
- Create: `Sources/HotkeyDetective/ProbeSession.swift`, `Sources/HotkeyDetective/HotkeyDetectiveApp.swift` (최소 MenuBarExtra, 뷰는 Task 10)

**Interfaces:**
- Produces:
  ```swift
  enum ProbeState { needsPermission, idle, listening, resolving(KeyCombo), result(KeyCombo, Verdict) }
  @MainActor final class ProbeSession: ObservableObject {
      @Published var state: ProbeState
      @Published var limitedMode: Bool
      static let reactionDelay: TimeInterval = 0.3
      func refreshPermission()
      func startListening()
      func cancelListening()
      func probe(manual combo: KeyCombo)     // 제한 모드: probe nil
      func reset()
  }
  ```

- [ ] **Step 1: ProbeSession 구현**

```swift
import AppKit
import Combine
import Engine
import Probe

enum ProbeState {
    case needsPermission, idle, listening
    case resolving(KeyCombo)
    case result(KeyCombo, Verdict)
}

@MainActor
final class ProbeSession: ObservableObject {
    @Published var state: ProbeState = .idle
    @Published var limitedMode = false

    static let reactionDelay: TimeInterval = 0.3
    private let listener = EventTapListener(timeout: 15)
    private var permissionPoll: Timer?
    private var before: SystemState?

    init() { refreshPermission() }

    var resolvers: [Resolver] {
        [SystemHotkeyResolver(),
         CarbonOccupancyResolver(registrar: CarbonHotKeyRegistrar()),
         ReactionResolver()] + KnownApps.all(running: WorkspaceRunningApps())
    }

    func refreshPermission() {
        if AccessibilityGate.isTrusted(prompt: false) || limitedMode {
            permissionPoll?.invalidate(); permissionPoll = nil
            if case .needsPermission = state { state = .idle }
        } else {
            state = .needsPermission
            if permissionPoll == nil {
                permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.refreshPermission() }
                }
            }
        }
    }

    func requestPermission() {
        _ = AccessibilityGate.isTrusted(prompt: true)
        AccessibilityGate.openSettings()
    }

    func useLimitedMode() { limitedMode = true; refreshPermission() }

    func startListening() {
        before = SystemSnapshot.capture()
        state = .listening
        listener.start { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .combo(let c): self.resolve(c, withProbe: true)
            case .cancelled, .timedOut: self.state = .idle
            case .tapFailed: self.limitedMode = false; self.state = .needsPermission
            }
        }
    }

    func cancelListening() { listener.stop(); state = .idle }

    func probe(manual combo: KeyCombo) { resolve(combo, withProbe: false) }

    func reset() { state = .idle }

    private func resolve(_ combo: KeyCombo, withProbe: Bool) {
        state = .resolving(combo)
        let run: (ProbeSnapshot?) -> Void = { [weak self] snap in
            guard let self else { return }
            let evidence = self.resolvers.flatMap { $0.resolve(combo, probe: snap) }
            self.state = .result(combo, VerdictBuilder.build(evidence))
        }
        guard withProbe, let before else { run(nil); return }
        let start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reactionDelay) {
            let after = SystemSnapshot.capture()
            run(ProbeSnapshot(before: before, after: after, elapsed: Date().timeIntervalSince(start), selfPID: getpid()))
        }
    }
}
```

- [ ] **Step 2: 최소 App 진입점**

`HotkeyDetectiveApp.swift`:
```swift
import SwiftUI

@main
struct HotkeyDetectiveApp: App {
    @StateObject private var session = ProbeSession()

    var body: some Scene {
        MenuBarExtra("HotkeyDetective", systemImage: "keyboard.badge.ellipsis") {
            RootView().environmentObject(session).frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}

struct RootView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        Text("상태: \(String(describing: session.state))").padding()
    }
}
```

- [ ] **Step 3: 빌드 확인**

Run: `rm Sources/HotkeyDetective/main.swift && swift build`
Expected: 성공. (`@main`과 `main.swift` 공존 불가이므로 삭제 필수)

- [ ] **Step 4: 커밋**

```bash
git add -A && git commit -m "feat(app): probe session state machine and MenuBarExtra entry

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Views — Permission / Probe / Verdict / ManualCombo

**Files:**
- Create: `Sources/HotkeyDetective/Views/PermissionView.swift`, `ProbeView.swift`, `VerdictView.swift`, `ManualComboView.swift`
- Modify: `Sources/HotkeyDetective/HotkeyDetectiveApp.swift` (`RootView` 교체)

**Interfaces:**
- Consumes: `ProbeSession`, `ProbeState`, `Verdict`, `Evidence`, `Owner.displayName`, `KeyCombo.display`, `KeyCodeNames.table`

- [ ] **Step 1: RootView 분기**

```swift
struct RootView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        Group {
            switch session.state {
            case .needsPermission: PermissionView()
            case .idle: ProbeView()
            case .listening: ListeningView()
            case .resolving(let c): VStack { Text(c.display).font(.largeTitle); ProgressView() }.padding()
            case .result(let c, let v): VerdictView(combo: c, verdict: v)
            }
        }
        .frame(width: 360)
    }
}
```

- [ ] **Step 2: PermissionView**

```swift
import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("손쉬운 사용 권한이 필요합니다", systemImage: "hand.raised")
                .font(.headline)
            Text("어떤 앱이 단축키에 반응하는지 보려면 키 입력을 관찰해야 합니다. 입력은 가로채거나 저장하지 않습니다.")
                .font(.callout).foregroundStyle(.secondary)
            Button("시스템 설정 열기") { session.requestPermission() }
                .buttonStyle(.borderedProminent)
            Button("권한 없이 제한 모드 사용") { session.useLimitedMode() }
                .buttonStyle(.link).font(.caption)
        }
        .padding()
    }
}
```

- [ ] **Step 3: ProbeView + ListeningView**

```swift
import SwiftUI
import Engine

struct ProbeView: View {
    @EnvironmentObject var session: ProbeSession
    @State private var showManual = false
    var body: some View {
        VStack(spacing: 12) {
            if session.limitedMode {
                Text("제한 모드 — 설정 파일 기반으로만 판정합니다").font(.caption).foregroundStyle(.orange)
            } else {
                Button("탐침 시작") { session.startListening() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            Button(showManual ? "조합 직접 지정 닫기" : "조합을 직접 지정") { showManual.toggle() }
                .buttonStyle(.link).font(.caption)
            if showManual || session.limitedMode {
                ManualComboView { session.probe(manual: $0) }
            }
        }
        .padding()
    }
}

struct ListeningView: View {
    @EnvironmentObject var session: ProbeSession
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 12) {
            Circle().fill(.blue).frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
                .onAppear { pulse = true }
            Text("지금 조합을 눌러보세요").font(.headline)
            Text("Esc로 취소 · 15초 후 자동 종료").font(.caption).foregroundStyle(.secondary)
            Button("취소") { session.cancelListening() }.buttonStyle(.link)
        }
        .padding()
    }
}
```

- [ ] **Step 4: ManualComboView**

```swift
import SwiftUI
import Engine

struct ManualComboView: View {
    var onProbe: (KeyCombo) -> Void
    @State private var mods: Modifiers = [.command]
    @State private var keyCode: UInt16 = 21

    private let keys = KeyCodeNames.table.sorted { $0.value < $1.value }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("⌃", isOn: binding(.control)); Toggle("⌥", isOn: binding(.option))
                Toggle("⇧", isOn: binding(.shift)); Toggle("⌘", isOn: binding(.command)); Toggle("fn", isOn: binding(.function))
            }
            .toggleStyle(.button)
            Picker("키", selection: $keyCode) {
                ForEach(keys, id: \.key) { Text($0.value).tag($0.key) }
            }
            Button("조회: \(KeyCombo(keyCode: keyCode, modifiers: mods).display)") {
                onProbe(KeyCombo(keyCode: keyCode, modifiers: mods))
            }
            .disabled(mods.isEmpty)
        }
    }

    private func binding(_ m: Modifiers) -> Binding<Bool> {
        Binding(get: { mods.contains(m) }, set: { if $0 { mods.insert(m) } else { mods.remove(m) } })
    }
}
```

- [ ] **Step 5: VerdictView**

```swift
import AppKit
import SwiftUI
import Engine

struct VerdictView: View {
    @EnvironmentObject var session: ProbeSession
    let combo: KeyCombo
    let verdict: Verdict

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(combo.display).font(.system(size: 34, weight: .semibold, design: .rounded))
            headline
            DisclosureGroup("근거 \(verdict.evidence.count)건", isExpanded: .constant(true)) {
                ForEach(Array(verdict.evidence.enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .top, spacing: 8) {
                        dots(e.confidence)
                        VStack(alignment: .leading) {
                            Text(e.source).font(.caption.bold())
                            Text(e.rationale).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if case .occupiedUnknown = verdict {
                Text("아직 모르는 앱일 수 있어요. 짐작 가는 앱을 종료하고 다시 시도해보세요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                ownerAction
                Spacer()
                Button("결과 복사") { copy() }
                Button("다시 탐침") { session.reset() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    @ViewBuilder private var headline: some View {
        switch verdict {
        case .confirmed(let o, _): styled("\(o.displayName)이(가) 사용 중", .blue)
        case .likely(let o, _): styled("\(o.displayName)이(가) 사용 중인 것으로 보임", .blue)
        case .contested(let os, _): styled(os.map(\.displayName).joined(separator: "와 ") + "이(가) 모두 등록함", .orange)
        case .occupiedUnknown: styled("어떤 앱이 점유 중이지만 누구인지 찾지 못함", .gray)
        case .free: styled("아무도 사용하지 않음", .green)
        }
    }

    private func styled(_ s: String, _ c: Color) -> some View {
        Text(s).font(.headline).foregroundStyle(c)
    }

    private func dots(_ c: Confidence) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                Circle().fill(i <= c.rawValue ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 5, height: 5)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var ownerAction: some View {
        switch primaryOwner {
        case .system?:
            Button("키보드 단축키 설정 열기") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
            }
        case .app(let bid, let name, _)?:
            Button("\(name) 열기") {
                NSRunningApplication.runningApplications(withBundleIdentifier: bid).first?.activate()
            }
        case nil: EmptyView()
        }
    }

    private var primaryOwner: Owner? {
        switch verdict {
        case .confirmed(let o, _), .likely(let o, _): return o
        case .contested(let os, _): return os.first
        default: return nil
        }
    }

    private func copy() {
        var s = "\(combo.display)\n"
        switch verdict {
        case .confirmed(let o, _): s += "사용 중: \(o.displayName)\n"
        case .likely(let o, _): s += "사용 중(추정): \(o.displayName)\n"
        case .contested(let os, _): s += "충돌: \(os.map(\.displayName).joined(separator: ", "))\n"
        case .occupiedUnknown: s += "점유됨(소유자 미상)\n"
        case .free: s += "비어 있음\n"
        }
        for e in verdict.evidence { s += "- [\(e.source)] \(e.rationale)\n" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
```

- [ ] **Step 6: 빌드 + 수동 확인**

Run: `swift build && .build/debug/HotkeyDetective`
- 메뉴바 아이콘 등장, 클릭 시 팝오버.
- 권한 없으면 PermissionView → "시스템 설정 열기" → 허용 후 1초 내 idle로 자동 전환.
- 탐침 시작 → ⌘⇧4 → confirmed 카드, 근거 1건 이상, "키보드 단축키 설정 열기" 버튼.
- 제한 모드 → ⌘⇧4 직접 지정 → confirmed(시스템 단축키만).
- 결과 복사 → 텍스트 에디터에 붙여넣기 확인.

- [ ] **Step 7: 커밋**

```bash
git add -A && git commit -m "feat(app): permission, probe, manual combo and verdict views

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: .app 번들 스크립트, LSUIElement, 로그인 항목, 종료 메뉴

**Files:**
- Create: `Resources/Info.plist`, `Scripts/bundle.sh`, `README.md`
- Modify: `Sources/HotkeyDetective/HotkeyDetectiveApp.swift` (우클릭 메뉴 대신 팝오버 하단 메뉴 — `MenuBarExtra` `.window` 스타일은 우클릭 메뉴가 없으므로 팝오버 하단에 작은 메뉴 버튼을 둔다)

**Interfaces:**
- Consumes: `ServiceManagement.SMAppService.mainApp`

- [ ] **Step 1: Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.goodbug.HotkeyDetective</string>
  <key>CFBundleName</key><string>HotkeyDetective</string>
  <key>CFBundleExecutable</key><string>HotkeyDetective</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
```

- [ ] **Step 2: bundle.sh**

```bash
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
codesign --force --sign - "$APP"      # ad-hoc. 배포 시 Developer ID로 교체
echo "built $APP"
```
`chmod +x Scripts/bundle.sh`

- [ ] **Step 3: 설정 메뉴 (로그인 시 실행, 종료)**

`HotkeyDetectiveApp.swift`의 `RootView` 하단에 추가:
```swift
import ServiceManagement

struct FooterMenu: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        HStack {
            Toggle("로그인 시 실행", isOn: $launchAtLogin)
                .toggleStyle(.checkbox).font(.caption)
                .onChange(of: launchAtLogin) { _, on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                }
            Spacer()
            Button("종료") { NSApplication.shared.terminate(nil) }.buttonStyle(.link).font(.caption)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }
}
```
`RootView`의 `Group { ... }` 아래에 `Divider(); FooterMenu()`를 `VStack(spacing: 0)`으로 감싸 추가.

- [ ] **Step 4: README.md**

```markdown
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
```

- [ ] **Step 5: 번들 실행 + 최종 수동 체크리스트**

Run: `Scripts/bundle.sh debug && open build/HotkeyDetective.app`
- Dock에 아이콘 없음, 메뉴바에만 표시.
- 번들 앱으로 손쉬운 사용 권한 재허용(터미널과 별개).
- ⌘⇧4 → confirmed(영역 스크린샷)
- ⌃⌥⌘F12 → free
- ⌘Space → confirmed(Spotlight) + 반응 감지 증거(Spotlight 창)
- Rectangle/Maccy/Raycast 중 설치 가능한 것 하나를 설치해 해당 조합 → likely/confirmed, 종료 후 → free + low 경고 표시
- 로그인 시 실행 토글 on/off 오류 없음
- 종료 버튼 동작

- [ ] **Step 6: 커밋**

```bash
git add -A && git commit -m "feat(app): app bundle script, LSUIElement, launch-at-login, README

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review 결과

- **스펙 커버리지:** 2절 결정사항(Task 1, 11) · 5절 타입(Task 1–2) · 6절 Resolver 4종(Task 3–6; 1Password/Alfred는 스펙 6.4의 "확인 안 되면 제외" 조항에 따라 v1 제외, README에 3개만 명시) · 7절 규칙(Task 2) · 8절 Probe(Task 7–8) · 9절 UI(Task 9–11) · 10절 에러(Task 4, 6, 8, 9) · 11절 테스트(Task 1–6 단위, Task 7·8·10·11 수동) · 13절 검증 항목(Task 3 Step 6, Task 7 Step 5, Task 8 Step 2).
- **스펙과의 차이:** 스펙 9절 "우클릭 메뉴"는 `MenuBarExtra(.window)`가 우클릭을 지원하지 않아 팝오버 하단 `FooterMenu`로 대체. 스펙 6.4의 Alfred·1Password는 이 머신에 설치돼 있지 않고 포맷 확신이 없어 v1에서 제외 — 추가는 `KnownAppDescriptor` 하나 + 픽스처 하나로 가능.
- **타입 일관성:** `Resolver.resolve(_:probe:)`, `ProbeSnapshot(before:after:elapsed:selfPID:)`, `SystemState(windows:frontmostPID:apps:)`, `KnownApps.all(running:)`, `ProbeSession.reactionDelay` — 전 태스크에서 동일하게 사용.
