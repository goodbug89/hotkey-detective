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
        // custom28 픽스처에 없는 ID 999를 enabled로 넣은 임시 plist (mask 1048576 = ⌘)
        let r = SystemHotkeyResolver(plistURL: tempPlist(["999": ["enabled": true,
            "value": ["parameters": [65535, 111, 1048576], "type": "standard"]]]))
        let e = r.resolve(KeyCombo(keyCode: 111, modifiers: [.command]), probe: nil)
        XCTAssertEqual(e.first?.owner, .system(feature: "시스템 기능 #999"))
    }

    /// plist 마스크에 fn 비트(8388608)가 섞여 있어도 fn 없는 조합으로 매칭돼야 한다.
    func testPlistMaskIgnoresFunctionBit() {
        let r = SystemHotkeyResolver(plistURL: tempPlist(["32": ["enabled": true,
            "value": ["parameters": [65535, 126, 8650752], "type": "standard"]]]))
        let e = r.resolve(KeyCombo(keyCode: 126, modifiers: [.control]), probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.owner, .system(feature: "Mission Control"))
    }

    // MARK: 기본 비활성 항목 (F2/F3)

    func testDefaultDisabledZoomToggleGivesNothing() {
        // ⌥⌘8 (id 15): 접근성 확대/축소 전환은 조합이 예약돼 있으나 기본 비활성
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 28, modifiers: [.command, .option]), probe: nil).isEmpty)
    }

    func testDefaultDisabledDesktopSwitchGivesNothing() {
        // ⌃1 (id 118): 데스크탑 직접 전환은 기본 비활성
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        XCTAssertTrue(r.resolve(KeyCombo(keyCode: 18, modifiers: [.control]), probe: nil).isEmpty)
    }

    func testDockAutoHideIsSingleEvidence() {
        // ⌥⌘D (id 52): 삭제된 id 7과 중복되지 않고 정확히 하나만 나와야 한다
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        let e = r.resolve(KeyCombo(keyCode: 2, modifiers: [.command, .option]), probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .system(feature: "Dock 자동 숨기기 전환"))
    }

    func testFullScreenshotFeatureName() {
        let r = SystemHotkeyResolver(plistURL: fixture("symbolichotkeys-default"))
        let e = r.resolve(KeyCombo(keyCode: 20, modifiers: [.command, .shift]), probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .system(feature: "전체 화면 스크린샷 저장"))
    }

    func testNoTwoDefaultEnabledEntriesShareACombo() {
        var seen: [KeyCombo: String] = [:]
        for (id, d) in SymbolicHotKeyDefaults.entries {
            guard d.defaultEnabled, let combo = d.combo else { continue }
            if let other = seen[combo] {
                XCTFail("\(combo.display)이(가) '\(other)'와(과) id \(id) '\(d.feature)'에 중복 배정됨")
            }
            seen[combo] = d.feature
        }
    }

    private func tempPlist(_ hotkeys: [String: Any]) -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("shk-\(UUID()).plist")
        let dict: [String: Any] = ["AppleSymbolicHotKeys": hotkeys]
        try! PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: tmp)
        return tmp
    }
}
