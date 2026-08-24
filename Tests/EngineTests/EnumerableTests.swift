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
