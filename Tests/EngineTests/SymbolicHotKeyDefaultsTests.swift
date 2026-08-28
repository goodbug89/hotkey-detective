import XCTest
@testable import Engine

/// 손으로 유지하던 기본값 표가 틀려서 certain 오판을 냈던 문제(ID 7/57/59/175 오류,
/// 22개 누락)의 재발을 막는다. 이제 출처는 macOS의 DefaultShortcutsTable.xml이고,
/// 여기서는 그 표와 우리 폴백·파싱이 어긋나지 않는지 고정한다.
final class SymbolicHotKeyDefaultsTests: XCTestCase {

    /// 폴백과 시스템 표는 **겹치는 ID에서** 값이 같아야 한다.
    ///
    /// 집합이 같은지는 단언하지 않는다. 표는 macOS 버전마다 다르다 — 예컨대 창 타일링
    /// 항목(237~251)은 macOS 15에서 추가됐고 14에는 없다. 폴백은 생성한 머신의 스냅샷이므로
    /// 다른 버전에서 집합이 갈리는 것은 정상이며, 그걸 실패로 처리하면 CI가 OS 버전에
    /// 묶여버린다. 정말 중요한 것은 같은 ID를 두 출처가 다르게 말하지 않는 것이다.
    func testFallbackAgreesWithSystemTableWhereTheyOverlap() throws {
        guard let rows = SymbolicHotKeyDefaults.parseSystemTable(at: SymbolicHotKeyDefaults.systemTableURL) else {
            throw XCTSkip("이 머신에 시스템 단축키 표가 없다 — 폴백 검증 생략")
        }
        XCTAssertFalse(rows.isEmpty, "시스템 표를 읽었는데 비어 있다면 파서가 깨진 것")
        let fallback = Dictionary(GeneratedShortcutTable.rows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var overlap = 0
        for row in rows {
            guard let f = fallback[row.id] else { continue }
            overlap += 1
            XCTAssertEqual(f.keyCode, row.keyCode, "ID \(row.id)의 keyCode가 두 출처에서 다르다")
            XCTAssertEqual(f.modifier, row.modifier, "ID \(row.id)의 modifier가 두 출처에서 다르다")
            XCTAssertEqual(f.enabled, row.enabled, "ID \(row.id)의 기본 활성 여부가 두 출처에서 다르다")
        }
        XCTAssertGreaterThan(overlap, 30, "겹치는 항목이 거의 없다면 폴백이나 파서가 잘못됐다")
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
    /// 변환 로직 자체는 시스템 표와 무관하게 검증한다 — 순수 함수이므로 OS 버전을 타지 않는다.
    /// (fn|control = 8650752)
    func testFunctionArrowsBecomeNavigationKeys() {
        func c(_ key: UInt16) -> KeyCombo? { SymbolicHotKeyDefaults.combo(keyCode: key, modifier: 8650752) }
        XCTAssertEqual(c(123), KeyCombo(keyCode: 115, modifiers: [.control]), "fn+← = ⌃Home")
        XCTAssertEqual(c(124), KeyCombo(keyCode: 119, modifiers: [.control]), "fn+→ = ⌃End")
        XCTAssertEqual(c(126), KeyCombo(keyCode: 116, modifiers: [.control]), "fn+↑ = ⌃PgUp")
        XCTAssertEqual(c(125), KeyCombo(keyCode: 121, modifiers: [.control]), "fn+↓ = ⌃PgDn")
    }

    /// 실제 표에 타일링 항목이 있는 OS에서는 위 변환이 실제로 적용됐는지도 본다.
    func testTilingEntriesUseNavigationKeysWhenPresent() throws {
        let e = SymbolicHotKeyDefaults.entries
        guard let tileLeft = e[240] else {
            throw XCTSkip("이 macOS 버전에는 창 타일링 단축키(ID 240)가 없다")
        }
        XCTAssertEqual(tileLeft.combo, KeyCombo(keyCode: 115, modifiers: [.control]), "타일 왼쪽 = ⌃Home")
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
        XCTAssertTrue(dupes.isEmpty, "같은 조합을 가진 활성 항목: \(dupes.mapValues { $0.sorted() }) — fn 변환이 충돌을 만들었을 수 있다")
    }

    /// fn을 남긴 항목(fn+문자키)은 탭 조합과 절대 일치하지 않아야 한다 —
    /// 인벤토리에는 보이되 탐침에서 거짓 매칭을 만들지 않기 위해서다.
    func testFunctionLetterEntriesKeepFunctionAndCannotMatchTapCombos() {
        // 변환 대상이 아닌 fn 조합(fn+F, keyCode 3)은 fn을 유지해야 한다.
        let fill = SymbolicHotKeyDefaults.combo(keyCode: 3, modifier: 8650752)
        XCTAssertTrue(fill?.modifiers.contains(.function) ?? false, "fn+문자키는 fn 유지")
        // 탭에서 온 조합은 Modifiers(cgFlags:)로 만들어지므로 fn이 없다 —
        // 따라서 이런 항목은 인벤토리에는 보이되 탐침에서 거짓 매칭을 만들지 않는다.
        let fromTap = Modifiers(cgFlags: (1 << 23) | (1 << 18))
        XCTAssertFalse(fromTap.contains(.function))
        XCTAssertNotEqual(fill?.modifiers, fromTap)
    }
}
