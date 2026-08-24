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

    private func owners(of verdict: Verdict) -> [Owner] {
        switch verdict {
        case .confirmed(let o, _), .likely(let o, _): return [o]
        case .contested(let os, _): return os
        case .occupiedUnknown, .free: return []
        }
    }

    /// InventoryBuilder.mergeOwners와 VerdictBuilder.uniqueOwners는 같은 병합 규칙을
    /// 따로 구현하고 있다. 한쪽만 바뀌면 목록과 판정이 어긋나므로 같은 증거에서
    /// 같은 소유자 집합(Owner.identity 기준)이 나오는지 고정한다.
    func testInventoryAndVerdictAgreeOnOwnerSet() {
        let noAction = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: nil)
        let unowned = Evidence(source: "t", owner: nil, confidence: .high, rationale: "r")
        let cases: [[Evidence]] = [
            [ev(sys, .certain)],
            [ev(sys, .certain), ev(maccy, .high)],
            [ev(noAction, .high, src: "a"), ev(maccy, .high, src: "b")],
            [ev(maccy, .medium), ev(scr, .medium)],
            [unowned, ev(maccy, .high)],
            [unowned],
        ]
        for evidence in cases {
            let inventory = InventoryBuilder.build(evidence.map { (space, $0) })[0].owners
            let verdict = owners(of: VerdictBuilder.build(evidence))
            XCTAssertEqual(Set(inventory.map(\.identity)), Set(verdict.map(\.identity)),
                           "증거 \(evidence.map(\.source))에서 소유자 집합이 갈렸다")
        }
    }

    func testConflictsSortedFirst() {
        let entries = InventoryBuilder.build([(a4, ev(scr, .certain)),
                                              (space, ev(sys, .certain)), (space, ev(maccy, .medium))])
        XCTAssertTrue(entries[0].isConflict)
        XCTAssertEqual(entries[0].combo, space)
        XCTAssertFalse(entries[1].isConflict)
    }
}
