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
                guard case .knownApp(_, _, _, let isRunning) = e.first!.reason else {
            return XCTFail("알려진 앱 근거여야 한다")
        }
        XCTAssertFalse(isRunning, "미실행 앱은 근거에 그 사실이 담겨야 한다")
    }

    func testRectangleDefaultTableUsedWhenPlistLacksAction() {
        // 실제 Rectangle plist에는 기본 단축키가 없다 — leftHalf는 Recommended 기본 테이블에서 와야 한다
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: ["com.knollsoft.Rectangle"]))
        let e = r.resolve(KeyCombo(keyCode: 45, modifiers: [.control, .option]), probe: nil)   // reflowTodo (plist)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "reflowTodo"))
    }

    func testRectanglePlistOverridesDefault() {
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: []))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 124, modifiers: [.control, .option]), probe: nil).isEmpty, "기본 ⌃⌥→는 덮어써져야 함")
        XCTAssertEqual(r.resolve(KeyCombo(keyCode: 124, modifiers: [.option, .command]), probe: nil).first?.owner,
                       .app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "rightHalf"))
    }

    func testRectangleEmptyEntryDisablesDefault() {
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: []))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 126, modifiers: [.control, .option]), probe: nil).isEmpty, "topHalf 빈 dict = 해제")
    }

    func testRectangleSpectacleSetWhenFlagAbsent() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("rect-\(UUID()).plist")
        try! PropertyListSerialization.data(fromPropertyList: ["SUHasLaunchedBefore": true], format: .xml, options: 0).write(to: tmp)
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: tmp, running: Running(ids: []))
        XCTAssertEqual(r.resolve(KeyCombo(keyCode: 123, modifiers: [.option, .command]), probe: nil).first?.owner,
                       .app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "leftHalf"))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil).isEmpty)
    }

    func testCandidateFileURLsPickFirstExisting() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cand-\(UUID())")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let missing = dir.appendingPathComponent("missing.plist")
        let present = dir.appendingPathComponent("present.plist")
        try! FileManager.default.copyItem(at: fixture("maccy"), to: present)
        let d = KnownAppDescriptor(bundleID: "org.p0deje.Maccy", name: "Maccy", candidateFileURLs: [missing, present], parse: KnownApps.maccy.parse)
        XCTAssertEqual(d.resolvedFileURL, present)
        let e = KnownAppResolver(descriptor: d, running: Running(ids: [])).resolve(KeyCombo(keyCode: 9, modifiers: [.command, .shift]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"))
    }

    func testMaccyDescriptorPrefersSandboxContainer() {
        XCTAssertTrue(KnownApps.maccy.candidateFileURLs[0].path.contains("Library/Containers/org.p0deje.Maccy/"))
    }

    func testMaccyCarbonFormat() {
        let r = KnownAppResolver(descriptor: KnownApps.maccy, fileURL: fixture("maccy"), running: Running(ids: ["org.p0deje.Maccy"]))
        let e = r.resolve(KeyCombo(keyCode: 9, modifiers: [.command, .shift]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"))
    }

    func testRaycastStringFormat() {
        let r = KnownAppResolver(descriptor: KnownApps.raycast, fileURL: fixture("raycast"), running: Running(ids: ["com.raycast.macos"]))
        let e = r.resolve(KeyCombo(keyCode: 49, modifiers: [.option]), probe: nil)
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.raycast.macos", name: "Raycast", action: "globalHotkey"))
    }

    func testNonMatchingComboGivesNothing() {
        let r = KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("rectangle"), running: Running(ids: []))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 0, modifiers: [.command]), probe: nil).isEmpty)
    }

    func testBrokenAndMissingFilesGiveNothing() {
        XCTAssertTrue(KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: fixture("broken"), running: Running(ids: [])).resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil).isEmpty)
        XCTAssertTrue(KnownAppResolver(descriptor: KnownApps.rectangle, fileURL: URL(fileURLWithPath: "/nope.plist"), running: Running(ids: [])).resolve(KeyCombo(keyCode: 123, modifiers: [.control, .option]), probe: nil).isEmpty)
    }

    func testAllBuildsOneResolverPerKnownApp() {
        XCTAssertEqual(KnownApps.all(running: Running(ids: [])).count, 5)
    }

    /// Engine은 표시 문구를 만들지 않는다 — 액션 이름은 앱 자신의 키에서 오는 식별자다.
    /// Raycast 서술자가 한국어 "호출"을 하드코딩하고 있었고, 그러면 나머지 14개 언어
    /// 화면에 한국어가 그대로 새어 나온다(시스템 기능명에서 한 번 겪은 문제다).
    func testDescriptorActionsAreLanguageNeutral() {
        let cases: [(KnownAppDescriptor, String)] = [
            (KnownApps.maccy, "maccy"), (KnownApps.rectangle, "rectangle"), (KnownApps.raycast, "raycast"),
        ]
        for (descriptor, name) in cases {
            let r = KnownAppResolver(descriptor: descriptor, fileURL: fixture(name),
                                     running: Running(ids: [descriptor.bundleID]))
            for e in r.allEvidence() {
                guard case .app(_, _, let action?) = e.owner else { continue }
                XCTAssertTrue(action.allSatisfy(\.isASCII),
                              "\(descriptor.name)의 액션 '\(action)'에 비ASCII 문자가 있다 — 지역화는 App 계층의 몫")
            }
        }
    }

    // MARK: AltTab

    /// AltTab은 단축키를 {string, secureData} 딕셔너리로 저장하고, secureData는
    /// ShortcutRecorder SRShortcut의 NSKeyedArchiver 아카이브다. 픽스처는 실제 설치에서
    /// 뽑았다 — hold는 ⌥(키 없음), next는 ⌥Q.
    func testAltTabParsesArchivedShortcut() {
        let r = KnownAppResolver(descriptor: KnownApps.altTab, fileURL: fixture("alttab"),
                                 running: Running(ids: ["com.lwouis.alt-tab-macos"]))
        let pairs = r.allPairs()
        // hold 트리거는 키가 없어(keyCode 65535) 조합이 되지 않으므로 제외된다.
        XCTAssertEqual(pairs.map(\.0), [KeyCombo(keyCode: 12, modifiers: [.option])])
        XCTAssertEqual(pairs.first?.1.owner,
                       .app(bundleID: "com.lwouis.alt-tab-macos", name: "AltTab",
                            action: "nextWindowShortcut3"))
    }

    /// keyCode 65535는 "키 없음"이다. 수정자만 쓰는 hold 트리거가 이 값을 쓰는데,
    /// 이를 조합으로 만들면 존재하지 않는 단축키를 인벤토리에 싣게 된다.
    func testAltTabTreats65535AsNoKey() throws {
        let d = NSDictionary(contentsOf: fixture("alttab")) as! [String: Any]
        let hold = try XCTUnwrap((d["holdShortcut3"] as? [String: Any])?["secureData"] as? Data)
        XCTAssertNil(KnownApps.parseAltTabShortcut(hold))
    }

    // MARK: Alfred

    /// Alfred는 메인 단축키를 설정 번들 안 hotkey/prefs.plist에 둔다.
    /// key는 가상 키코드, mod는 CG 수정자 비트다. 픽스처는 실제 설치에서 뽑았다 — ⌃⌥⌘J.
    func testAlfredParsesHotkey() {
        let r = KnownAppResolver(descriptor: KnownApps.alfred, fileURL: fixture("alfred"),
                                 running: Running(ids: ["com.runningwithcrayons.Alfred"]))
        let pairs = r.allPairs()
        XCTAssertEqual(pairs.map(\.0), [KeyCombo(keyCode: 38, modifiers: [.control, .option, .command])])
        XCTAssertEqual(pairs.first?.1.owner,
                       .app(bundleID: "com.runningwithcrayons.Alfred", name: "Alfred", action: "default"))
    }

    /// prefs.json을 읽을 수 없어도 후보가 비면 안 된다 — resolvedFileURL이 첫 원소를
    /// 꺼내므로 빈 배열은 크래시다.
    func testAlfredAlwaysOffersACandidatePath() {
        XCTAssertFalse(KnownApps.alfredHotkeyURLs.isEmpty)
        XCTAssertTrue(KnownApps.alfredHotkeyURLs[0].path.hasSuffix("hotkey/prefs.plist"))
    }
}
