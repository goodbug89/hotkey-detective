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
