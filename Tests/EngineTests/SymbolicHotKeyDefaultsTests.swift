import XCTest
@testable import Engine

/// 손으로 유지하던 기본값 표가 틀려서 certain 오판을 냈던 문제(ID 7/57/59/175 오류,
/// 22개 누락)의 재발을 막는다. 이제 출처는 macOS의 DefaultShortcutsTable.xml이고,
/// 여기서는 그 표와 우리 폴백·파싱이 어긋나지 않는지 고정한다.
final class SymbolicHotKeyDefaultsTests: XCTestCase {

    /// 생성된 폴백이 이 머신의 시스템 표와 같은 ID 집합을 담아야 한다.
    /// 어긋나면 `Scripts/gen-default-shortcuts.swift`를 다시 돌려야 한다는 신호다.
    func testGeneratedFallbackMatchesSystemTable() throws {
        guard let rows = SymbolicHotKeyDefaults.parseSystemTable(at: SymbolicHotKeyDefaults.systemTableURL) else {
            throw XCTSkip("이 머신에 시스템 단축키 표가 없다 — 폴백 검증 생략")
        }
        XCTAssertEqual(Set(rows.map(\.id)), Set(GeneratedShortcutTable.rows.map(\.id)),
                       "폴백이 시스템 표와 다르다 — Scripts/gen-default-shortcuts.swift 재실행 필요")
    }

    /// 시스템 표에서 확인된 사실들. 예전 손수 테이블은 이 넷을 전부 틀렸다.
    func testAuthoritativeEntriesThatUsedToBeWrong() throws {
        let e = SymbolicHotKeyDefaults.entries
        // ID 7 — 메뉴 막대 초점(⌃F2). 수정 웨이브에서 잘못 삭제했던 항목.
        XCTAssertEqual(e[7]?.combo, KeyCombo(keyCode: 120, modifiers: [.control]))
        // ID 57 — 상태 메뉴 초점(⌃F8). 예전엔 ⌃F7로 적혀 있었다.
        XCTAssertEqual(e[57]?.combo, KeyCombo(keyCode: 100, modifiers: [.control]))
        // ID 59 — VoiceOver(⌘F5). 예전엔 "메뉴 막대 이동 ⌃F2"로 완전히 잘못 붙어 있었다.
        XCTAssertEqual(e[59]?.combo, KeyCombo(keyCode: 96, modifiers: [.command]))
        XCTAssertEqual(e[59]?.feature, "VoiceOver 켜기/끄기")
        // ID 162 — 손쉬운 사용 제어(⌥⌘F5). 예전엔 이 조합을 175에 붙였다.
        XCTAssertEqual(e[162]?.combo, KeyCombo(keyCode: 96, modifiers: [.command, .option]))
        // ID 175 — 방해금지 모드, 기본 키 없음.
        XCTAssertNil(e[175]?.combo)
    }

    /// fn+화살표는 이벤트 탭에 내비게이션 키로 도착한다(fn+← = Home). 실기로 확인함:
    /// ⌃fn←를 탐침하면 앱이 ⌃Home으로 받았다. 그래서 표도 그 형태로 저장한다.
    func testFunctionArrowsBecomeNavigationKeys() {
        let e = SymbolicHotKeyDefaults.entries
        XCTAssertEqual(e[240]?.combo, KeyCombo(keyCode: 115, modifiers: [.control]), "타일 왼쪽 = ⌃Home")
        XCTAssertEqual(e[241]?.combo, KeyCombo(keyCode: 119, modifiers: [.control]), "타일 오른쪽 = ⌃End")
        XCTAssertEqual(e[242]?.combo, KeyCombo(keyCode: 116, modifiers: [.control]), "타일 위 = ⌃PgUp")
        XCTAssertEqual(e[243]?.combo, KeyCombo(keyCode: 121, modifiers: [.control]), "타일 아래 = ⌃PgDn")
    }

    /// 변환 후에도 Space 이동/Mission Control과 겹치지 않아야 한다.
    /// 겹치면 시스템 기능끼리 가짜 충돌이 난다.
    func testTilingDoesNotCollideWithSpaceSwitching() {
        let e = SymbolicHotKeyDefaults.entries
        XCTAssertEqual(e[79]?.combo, KeyCombo(keyCode: 123, modifiers: [.control]), "왼쪽 Space = ⌃←")
        XCTAssertNotEqual(e[79]?.combo, e[240]?.combo)
        XCTAssertNotEqual(e[32]?.combo, e[242]?.combo)
    }

    /// 활성 항목끼리 같은 조합을 갖지 않아야 한다 — 있으면 곧바로 가짜 contested가 된다.
    func testNoTwoEnabledEntriesShareACombo() {
        var byCombo: [KeyCombo: [Int]] = [:]
        for e in SymbolicHotKeyDefaults.all where e.defaultEnabled {
            if let c = e.combo { byCombo[c, default: []].append(e.id) }
        }
        let dupes = byCombo.filter { $0.value.count > 1 }
        XCTAssertTrue(dupes.isEmpty, "같은 조합을 가진 활성 항목: \(dupes.mapValues { $0.sorted() })")
    }

    /// fn을 남긴 항목(fn+문자키)은 탭 조합과 절대 일치하지 않아야 한다 —
    /// 인벤토리에는 보이되 탐침에서 거짓 매칭을 만들지 않기 위해서다.
    func testFunctionLetterEntriesKeepFunctionAndCannotMatchTapCombos() {
        let e = SymbolicHotKeyDefaults.entries
        XCTAssertTrue(e[237]?.combo?.modifiers.contains(.function) ?? false, "Fill은 fn 유지")
        // 탭에서 온 조합은 Modifiers(cgFlags:)로 만들어지므로 fn이 없다
        let fromTap = Modifiers(cgFlags: (1 << 23) | (1 << 18))
        XCTAssertFalse(fromTap.contains(.function))
        XCTAssertNotEqual(e[237]?.combo?.modifiers, fromTap)
    }
}
