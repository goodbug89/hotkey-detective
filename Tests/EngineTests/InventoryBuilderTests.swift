import XCTest
@testable import Engine

final class InventoryBuilderTests: XCTestCase {
    let a4 = KeyCombo(keyCode: 21, modifiers: [.command, .shift])
    let space = KeyCombo(keyCode: 49, modifiers: [.control])
    func ev(_ owner: Owner, _ c: Confidence = .high, src: String = "t") -> Evidence {
        Evidence(source: src, owner: owner, confidence: c, rationale: "r")
    }
    let sys = Owner.system(feature: "이전 입력 소스 선택")
    let maccy = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "togglePreview")
    let scr = Owner.system(feature: "영역 스크린샷")

    func testSingleOwnerIsNotConflict() {
        let entries = InventoryBuilder.build([(a4, ev(scr, .certain))])
        XCTAssertEqual(entries.count, 1)
        XCTAssertFalse(entries[0].isConflict)
        XCTAssertEqual(entries[0].owners, [scr])
    }

    func testDifferentOwnersSameComboIsConflict() {
        let entries = InventoryBuilder.build([(space, ev(sys, .certain)), (space, ev(maccy, .medium))])
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isConflict)
        XCTAssertEqual(Set(entries[0].owners.map(\.identity)), [sys.identity, maccy.identity])
        XCTAssertEqual(entries[0].evidence.count, 2)
    }

    func testSameOwnerActionMergesNoConflict() {
        let noAction = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: nil)
        let entries = InventoryBuilder.build([(space, ev(noAction)), (space, ev(maccy))])
        XCTAssertFalse(entries[0].isConflict, "같은 앱은 한 소유자")
        XCTAssertEqual(entries[0].owners.count, 1)
        XCTAssertEqual(entries[0].owners[0], maccy, "액션 있는 쪽 유지")
    }

    func testConflictsSortedFirst() {
        let entries = InventoryBuilder.build([(a4, ev(scr, .certain)),
                                              (space, ev(sys, .certain)), (space, ev(maccy, .medium))])
        XCTAssertTrue(entries[0].isConflict)
        XCTAssertEqual(entries[0].combo, space)
        XCTAssertFalse(entries[1].isConflict)
    }
}
