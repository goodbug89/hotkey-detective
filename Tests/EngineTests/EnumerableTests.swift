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
}
