import XCTest
@testable import Engine

final class KeyComboTests: XCTestCase {
    func testModifiersFromCGFlags() {
        // ⌘⇧ = command(1<<20) | shift(1<<17)
        let m = Modifiers(cgFlags: (1 << 20) | (1 << 17) | 0x100 /* 무관 비트 */)
        XCTAssertEqual(m, [.command, .shift])
        XCTAssertEqual(m.cgFlags, (1 << 20) | (1 << 17))
    }

    func testModifiersIgnoresFunctionBit() {
        // macOS는 화살표/F키 keyDown에 fn(1<<23)을 함께 세운다 — 무시해야 ⌃← 등이 매칭된다.
        XCTAssertEqual(Modifiers(cgFlags: (1 << 23) | (1 << 18)), [.control])
        XCTAssertEqual(Modifiers(cgFlags: 1 << 23), [])
    }

    func testModifiersCarbonRoundTrip() {
        let m: Modifiers = [.command, .option, .control, .shift]
        // cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096
        XCTAssertEqual(m.carbon, 256 | 512 | 2048 | 4096)
        XCTAssertEqual(Modifiers(carbon: 256 | 2048), [.command, .option])
    }

    func testDisplayOrderIsControlOptionShiftCommand() {
        let c = KeyCombo(keyCode: 21, modifiers: [.command, .shift])   // 4
        XCTAssertEqual(c.display, "⇧⌘4")
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
