import XCTest
@testable import Engine

final class EnumerableTests: XCTestCase {
    struct Running: RunningAppChecker { let ids: Set<String>; func isRunning(bundleID: String) -> Bool { ids.contains(bundleID) } }
    func fixture(_ n: String) -> URL { Bundle.module.url(forResource: n, withExtension: "plist", subdirectory: "Fixtures")! }

    /// 제외 목록은 실제 파서 서술자에서 파생돼야 한다 — 문자열을 손으로 적어두면
    /// 파서를 추가하고 목록을 갱신하지 않아도 테스트가 통과해버린다.
    func testParserBundleIDsCoversEveryKnownAppDescriptor() {
        XCTAssertEqual(KnownApps.parserBundleIDs,
                       Set([KnownApps.rectangle, KnownApps.maccy, KnownApps.raycast].map(\.bundleID)))
    }

    /// 같은 앱을 전용 파서와 휴리스틱 스캐너 양쪽에 먹여도 인벤토리에는 소유자가 하나만
    /// 남아야 한다(배타 할당 불변식). parserBundleIDs 제외가 실제로 이중 보고를 막는지
    /// resolver 두 개 → InventoryBuilder 끝단까지 통과시켜 확인한다.
    func testKnownParserAndScannerDoNotDoubleReportSameApp() {
        let plist = fixture("maccy")   // KeyboardShortcuts_ 패턴 — 스캐너도 인식하는 모양
        let parser = KnownAppResolver(descriptor: KnownApps.maccy, fileURL: plist,
                                      running: Running(ids: ["org.p0deje.Maccy"]))
        let scanner = HeuristicScanResolver(
            apps: [ScannableApp(bundleID: "org.p0deje.Maccy", name: "Maccy", plistURLs: [plist])],
            excludedBundleIDs: KnownApps.parserBundleIDs)
        let entries = InventoryBuilder.build(parser.allPairs() + scanner.allPairs())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].owners.count, 1)
        XCTAssertFalse(entries[0].isConflict)
        XCTAssertEqual(entries[0].owners[0], .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"))
        // 이 단언이 실제 회귀 핀이다. 위의 소유자 단언들은 제외 규칙을 없애도 통과한다 —
        // 스캐너가 내는 소유자가 파서와 동일해 Owner.identity 병합이 둘을 합쳐버리기 때문이다.
        // 이중 보고가 관측되는 유일한 지점은 증거 개수뿐이다.
        XCTAssertEqual(entries[0].evidence.count, 1,
                       "파서 담당 앱이 스캐너에도 잡히면 증거가 2건이 된다 — 배타 할당이 깨진 것")
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
                                       && $0.1.owner == .system(feature: "Save picture of selected area as a file") })
    }

    func testSystemResolverAllPairsExcludeDisabled() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-disabled28"))
        // disabled28 픽스처는 항목 30(영역 스크린샷)을 비활성화 → 목록에 없어야
        XCTAssertFalse(r.allPairs().contains { $0.1.owner == .system(feature: "Save picture of selected area as a file") })
    }
}
