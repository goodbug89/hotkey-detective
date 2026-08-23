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
