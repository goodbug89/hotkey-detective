import XCTest
@testable import Engine

/// 픽스처 출처: 이 맥의 실제 karabiner.json 골격(fn_function_keys 항등 매핑 12개 + 기기 항목)에
/// Karabiner가 직접 배포하는 complex_modifications_rules_example.json의 규칙 3개와
/// simple_modifications 한 항목(caps_lock → escape)을 넣었다. 선택되지 않은 두 번째 프로필도
/// 하나 둔다 — 무시돼야 한다.
final class KarabinerResolverTests: XCTestCase {
    func fixture() -> URL { Bundle.module.url(forResource: "karabiner", withExtension: "json", subdirectory: "Fixtures")! }
    func resolver(active: Bool = true) -> KarabinerResolver {
        KarabinerResolver(configURL: fixture(), isActive: { active })
    }

    /// 예제 규칙 "Change right_command+hjkl to arrow keys": right_command → ⌘, 좌우 구분 없음.
    func testComplexRuleMandatoryModifiersBecomeCombos() {
        let combos = Set(resolver().allPairs().map(\.0))
        for key in ["h", "j", "k", "l"] {
            let code = KarabinerKeyNames.keyCode(for: key)!
            XCTAssertTrue(combos.contains(KeyCombo(keyCode: code, modifiers: [.command])), "⌘\(key) 누락")
        }
        let hjkl = resolver().allPairs().first { $0.0 == KeyCombo(keyCode: 4, modifiers: [.command]) }
        XCTAssertEqual(hjkl?.1.owner, .app(bundleID: KarabinerResolver.bundleID, name: "Karabiner-Elements",
                                             action: "Change right_command+hjkl to arrow keys"))
    }

    /// caps_lock → f19처럼 F16–F20을 "하이퍼 키"로 쓰는 설정이 흔하다. 표에 없으면 그 규칙이
    /// 조용히 빠진다 — 실제로 f20 규칙을 넣고 렌더했더니 인벤토리에 안 나와서 발견했다.
    func testExtendedFunctionKeysAreNamed() {
        XCTAssertEqual(KarabinerKeyNames.keyCode(for: "f16"), 106)
        XCTAssertEqual(KarabinerKeyNames.keyCode(for: "f19"), 80)
        XCTAssertEqual(KarabinerKeyNames.keyCode(for: "f20"), 90)
        XCTAssertEqual(KeyCombo(keyCode: 80, modifiers: []).display, "F19")
    }

    /// Karabiner는 키를 등록하는 게 아니라 가로채는 것이라, 파서(설정) 뱃지가 아니라 전용
    /// 리매핑 뱃지를 달아야 한다. 문서·랜딩이 "여섯 번째 출처"라고 말하는 근거가 이것이다.
    func testEvidenceUsesDedicatedRemapSource() {
        let sources = Set(resolver().allPairs().map(\.1.source))
        XCTAssertFalse(sources.isEmpty)
        XCTAssertEqual(sources, [.keyRemap(appName: "Karabiner-Elements")])
    }

    /// `modifiers.optional: ["any"]`만 있고 mandatory가 없는 항목(caps_lock, spacebar 예제)은
    /// 맨 키 조합이다. mandatory에 `any`가 있으면 표현할 수 없어 뺀다.
    func testBareKeyManipulatorsAndAnyModifier() {
        let pairs = resolver().allPairs()
        XCTAssertTrue(pairs.contains { $0.0 == KeyCombo(keyCode: 49, modifiers: []) }, "spacebar 예제 누락")
        XCTAssertNil(KarabinerResolver.combo(from: ["key_code": "a", "modifiers": ["mandatory": ["any"]]]))
        XCTAssertNil(KarabinerResolver.combo(from: ["key_code": "no_such_key"]))
    }

    /// simple_modifications는 "from → to"를 액션으로. 항등 매핑(f1 → f1)은 동작을 바꾸지
    /// 않으므로 인벤토리에 실리면 안 된다 — 이 맥의 실제 설정에 12개가 있다.
    func testSimpleModificationsAndIdentityFnKeys() {
        let pairs = resolver().allPairs()
        let caps = pairs.first { $0.0 == KeyCombo(keyCode: 57, modifiers: []) }
        XCTAssertEqual(caps?.1.owner, .app(bundleID: KarabinerResolver.bundleID, name: "Karabiner-Elements",
                                            action: "caps_lock → escape"))
        for f in ["f1", "f5", "f12"] {
            let code = KarabinerKeyNames.keyCode(for: f)!
            XCTAssertFalse(pairs.contains { $0.0 == KeyCombo(keyCode: code, modifiers: []) }, "\(f) 항등 매핑이 실렸다")
        }
    }

    /// 선택된 프로필만 유효하다. 두 번째 프로필의 a → b는 나오면 안 된다.
    func testOnlySelectedProfileCounts() {
        XCTAssertFalse(resolver().allPairs().contains { $0.0 == KeyCombo(keyCode: 0, modifiers: []) })
    }

    /// 코어 서비스가 죽어 있으면 규칙도 죽은 것이다 — low로 내려 인벤토리에 dormant로 실린다.
    /// 근거는 "등록"이 아니라 "가로채기"다. knownApp을 재사용하면 "binds … to"로 읽혀
    /// 조합이 앱에 도달한다는 뜻이 되는데, 정반대다.
    func testReasonIsRemapNotKnownApp() {
        for active in [true, false] {
            let e = resolver(active: active).allEvidence().first!
            guard case .remap(let app, _, _, let isActive) = e.reason else {
                return XCTFail("remap이 아니라 \(e.reason)")
            }
            XCTAssertEqual(app, "Karabiner-Elements"); XCTAssertEqual(isActive, active)
        }
    }

    func testConfidenceFollowsServiceState() {
        XCTAssertTrue(resolver(active: true).allEvidence().allSatisfy { $0.confidence == .high })
        XCTAssertTrue(resolver(active: false).allEvidence().allSatisfy { $0.confidence == .low })
    }

    func testMissingConfigIsEmptyNotCrash() {
        let r = KarabinerResolver(configURL: URL(fileURLWithPath: "/nonexistent/karabiner.json"), isActive: { true })
        XCTAssertTrue(r.allPairs().isEmpty)
    }

    /// 순서는 결정적이어야 한다 — 두 번 읽어 같은지.
    func testOrderIsDeterministic() {
        XCTAssertEqual(resolver().allPairs().map(\.0), resolver().allPairs().map(\.0))
    }

    /// Karabiner가 배포하는 키 이름 목록의 모든 문자·숫자·기능·편집키를 우리 표가 안다.
    func testKeyNameTableCoversCommonKeys() {
        for n in ["a", "z", "0", "9", "spacebar", "return_or_enter", "escape", "f1", "f15",
                  "left_arrow", "page_down", "delete_forward", "grave_accent_and_tilde", "caps_lock"] {
            XCTAssertNotNil(KarabinerKeyNames.keyCode(for: n), "\(n) 없음")
        }
        XCTAssertEqual(KarabinerKeyNames.keyCode(for: "a"), 0)
        XCTAssertEqual(KarabinerKeyNames.keyCode(for: "1"), 18)
    }
}
