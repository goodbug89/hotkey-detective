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
        XCTAssertEqual(e[0].source, .heuristicScan)
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

    /// scan-mas-root.plist: keyCode/modifierFlags가 plist 루트에 바로 놓여 있어 액션 이름을
    /// 붙일 키가 없다. 예전에는 빈 문자열이 액션으로 들어가 "'' = ⌘T" 같은 문구가 나왔다.
    func testRootLevelMASPatternHasNilAction() {
        let r = HeuristicScanResolver(apps: [app("com.example.Root", "Root", ["scan-mas-root"])], excludedBundleIDs: [])
        let e = r.allEvidence()
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .app(bundleID: "com.example.Root", name: "Root", action: nil))
        // 루트 레벨 MAS 패턴은 액션 이름이 없다 — nil이어야 하며 빈 문자열이면 안 된다.
        guard case .scanPattern(let app, let action, _) = e[0].reason else {
            return XCTFail("스캔 근거여야 한다")
        }
        XCTAssertEqual(app, "Root")
        XCTAssertNil(action, "액션 없는 항목은 nil이어야 표시 계층이 빈 따옴표를 만들지 않는다")
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

    /// 샌드박스 컨테이너 plist는 읽는 순간 macOS가 권한을 묻는다. 기본 스캔은 컨테이너 경로를
    /// 아예 보지 않고, includeContainers를 켠 심층 스캔에서만 본다.
    func testContainerPlistOnlyReadWhenIncludeContainers() {
        let app = ScannableApp(bundleID: "com.example.Sandboxed", name: "Sandboxed",
                               plistURLs: [URL(fileURLWithPath: "/nope.plist")],
                               containerPlistURLs: [fx("scan-keyboardshortcuts")])
        XCTAssertTrue(HeuristicScanResolver(apps: [app], excludedBundleIDs: []).allEvidence().isEmpty)
        let deep = HeuristicScanResolver(apps: [app], excludedBundleIDs: [], includeContainers: true)
        XCTAssertEqual(deep.allEvidence().count, 2)   // popup + pin
    }

    func testAllPairsCountsEveryShortcut() {
        let r = HeuristicScanResolver(apps: [app("com.example.Clip", "Clip", ["scan-keyboardshortcuts"])], excludedBundleIDs: [])
        let pairs = r.allPairs()
        XCTAssertEqual(pairs.count, 2)  // popup, pin (showFooter는 무시)
        XCTAssertTrue(pairs.contains { $0.0 == KeyCombo(keyCode: 8, modifiers: [.command, .shift]) })
    }

    /// scan-tie.plist: 액션 "capture"가 MAS 패턴(keyCode 20)과 KeyboardShortcuts_ 패턴(keyCode 5)
    /// 양쪽에서 나오고, "zebra"(keyCode 30)가 하나 더 있다. Dictionary 순회 순서는 프로세스마다
    /// 무작위이므로, rationale 문자열만으로 정렬하면 출력 순서가 불안정할 수 있었다.
    /// (앱 인덱스, 액션, keyCode, modifiers) 4중 키 정렬은 이 순서를 항상
    /// action 오름차순("capture" < "zebra") → keyCode 오름차순(5 < 20)으로 고정한다.
    func testDeterministicOrderAcrossRepeatedCalls() {
        let r = HeuristicScanResolver(apps: [app("com.example.Tie", "Tie", ["scan-tie"])], excludedBundleIDs: [])
        let expectedActions = ["capture", "capture", "zebra"]
        let expectedKeyCodes: [UInt16] = [5, 20, 30]
        for _ in 0..<5 {
            let pairs = r.allPairs()
            let actions: [String?] = pairs.map {
                if case .app(_, _, let action) = $0.1.owner { return action }
                return nil
            }
            XCTAssertEqual(actions, expectedActions)
            XCTAssertEqual(pairs.map { $0.0.keyCode }, expectedKeyCodes)
        }
    }

    /// scan-array.plist: "bindings"라는 배열 값 안에 KeyboardShortcuts_ 패턴을 담은 딕셔너리가
    /// 중첩되어 있다. extract()의 배열 분기(else if let arr = any as? [Any])가 실제로 배열 원소까지
    /// 재귀하는지 검증한다.
    func testArrayRecursionFindsNestedShortcut() {
        let r = HeuristicScanResolver(apps: [app("com.example.Arr", "Arr", ["scan-array"])], excludedBundleIDs: [])
        // launch keyCode 12 carbon 2048 = ⌥
        let e = r.resolve(KeyCombo(keyCode: 12, modifiers: [.option]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.example.Arr", name: "Arr", action: "launch"))
    }
}
