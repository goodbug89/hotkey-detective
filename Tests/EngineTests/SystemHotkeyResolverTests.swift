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
