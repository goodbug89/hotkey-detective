import XCTest
@testable import Engine

final class VerdictBuilderTests: XCTestCase {
    let sys = Owner.system(feature: "영역 스크린샷")
    let ray = Owner.app(bundleID: "com.raycast.macos", name: "Raycast", action: nil)
    let rect = Owner.app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "왼쪽 절반")

    func ev(_ owner: Owner?, _ c: Confidence, src: String = "t") -> Evidence {
        Evidence(source: .knownAppParser(appName: src), owner: owner, confidence: c,
                 reason: .systemHotkey(id: 0, combo: "-"))
    }

    func testNoEvidenceIsFree() {
        guard case .free(let e) = VerdictBuilder.build([]) else { return XCTFail() }
        XCTAssertTrue(e.isEmpty)
    }

    func testSingleCertainIsConfirmed() {
        guard case .confirmed(let o, _) = VerdictBuilder.build([ev(sys, .certain)]) else { return XCTFail() }
        XCTAssertEqual(o, sys)
    }

    func testTwoCertainDifferentOwnersIsContested() {
        guard case .contested(let owners, _) = VerdictBuilder.build([ev(sys, .certain), ev(ray, .certain)]) else { return XCTFail() }
        XCTAssertEqual(Set(owners), [sys, ray])
    }

    func testCertainPlusHighSameOwnerStillConfirmed() {
        guard case .confirmed(let o, let e) = VerdictBuilder.build([ev(ray, .high), ev(ray, .certain)]) else { return XCTFail() }
        XCTAssertEqual(o, ray); XCTAssertEqual(e.count, 2)
    }

    func testSingleHighOwnerIsLikely() {
        guard case .likely(let o, _) = VerdictBuilder.build([ev(nil, .high), ev(ray, .high)]) else { return XCTFail() }
        XCTAssertEqual(o, ray)
    }

    func testMediumOnlyIsLikely() {
        guard case .likely(let o, _) = VerdictBuilder.build([ev(ray, .medium)]) else { return XCTFail() }
        XCTAssertEqual(o, ray)
    }

    func testTwoHighOwnersIsContested() {
        guard case .contested(let owners, _) = VerdictBuilder.build([ev(ray, .high), ev(rect, .medium)]) else { return XCTFail() }
        XCTAssertEqual(owners.first, ray, "높은 신뢰도 먼저")
        XCTAssertEqual(owners.count, 2)
    }

    func testOnlyNilOwnerIsOccupiedUnknown() {
        guard case .occupiedUnknown(let e) = VerdictBuilder.build([ev(nil, .high)]) else { return XCTFail() }
        XCTAssertEqual(e.count, 1)
    }

    func testLowOnlyIsFreeButKeepsEvidence() {
        guard case .free(let e) = VerdictBuilder.build([ev(rect, .low)]) else { return XCTFail() }
        XCTAssertEqual(e.count, 1)
    }

    func testSameAppWithAndWithoutActionIsOneOwnerKeepingAction() {
        let maccyNoAction = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: nil)
        let maccyPopup = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup")
        // 반응 감지(high, 액션 없음)가 정렬상 먼저 와도 액션 있는 쪽을 남겨야 한다
        guard case .likely(let o, let e) = VerdictBuilder.build([ev(maccyNoAction, .high, src: "반응 감지"), ev(maccyPopup, .high, src: "Maccy 설정")]) else { return XCTFail() }
        XCTAssertEqual(o, maccyPopup)
        XCTAssertEqual(e.count, 2)
    }

    func testDifferentAppsStillContested() {
        guard case .contested(let owners, _) = VerdictBuilder.build([ev(ray, .high), ev(rect, .high)]) else { return XCTFail() }
        XCTAssertEqual(owners.count, 2)
    }

    func testCertainPlusDifferentHighOwnerIsContested() {
        // 시스템 단축키(certain) + 다른 앱의 설정 증거(high) = 실제 충돌
        guard case .contested(let owners, _) = VerdictBuilder.build([ev(sys, .certain), ev(ray, .high)]) else { return XCTFail() }
        XCTAssertEqual(owners, [sys, ray], "certain이 먼저")
    }

    func testCertainPlusDifferentMediumOwnerStaysConfirmed() {
        // medium(2개 앱 반응 등)은 contested를 일으킬 만큼 강하지 않다
        guard case .confirmed(let o, _) = VerdictBuilder.build([ev(sys, .certain), ev(ray, .medium)]) else { return XCTFail() }
        XCTAssertEqual(o, sys)
    }

    // MARK: - 실기 검증된 네 조합을 고정한다 (v1에서 규칙을 고친 뒤 ⌘Space를 다시
    // 확인하지 않아 confirmed → contested 회귀가 생겼었다. 그 재발을 막는 테스트들.)

    /// ⌘Space: 시스템이 소유하고 시스템 UI(Spotlight)가 반응. 반응은 관찰이므로 라이벌이 아니다.
    func testCertainPlusReactionObservationStaysConfirmed() {
        let spotlightSystem = Owner.system(feature: "Spotlight 검색")
        let spotlightApp = Owner.app(bundleID: "com.apple.Spotlight", name: "Spotlight", action: nil)
        let evidence = [
            Evidence(source: .systemHotkeys, owner: spotlightSystem, confidence: .certain,
                     reason: .systemHotkey(id: 0, combo: "-"), kind: .claim),
            Evidence(source: .reaction, owner: spotlightApp, confidence: .high,
                     reason: .systemHotkey(id: 0, combo: "-"), kind: .observation),
        ]
        guard case .confirmed(let o, let e) = VerdictBuilder.build(evidence) else {
            return XCTFail("반응 증거는 시스템 소유를 뒤집지 못한다")
        }
        XCTAssertEqual(o, spotlightSystem)
        XCTAssertEqual(e.count, 2, "근거 목록에는 반응도 그대로 남는다")
    }

    /// ⌃Space: 시스템 소유 + Maccy의 **설정** 주장 → 진짜 충돌이므로 contested 유지.
    func testCertainPlusParserClaimIsStillContested() {
        let inputSource = Owner.system(feature: "이전 입력 소스 선택")
        let maccyPreview = Owner.app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "togglePreview")
        let evidence = [
            Evidence(source: .systemHotkeys, owner: inputSource, confidence: .certain,
                     reason: .systemHotkey(id: 0, combo: "-"), kind: .claim),
            Evidence(source: .systemHotkeys, owner: maccyPreview, confidence: .high,
                     reason: .systemHotkey(id: 0, combo: "-"), kind: .claim),
        ]
        guard case .contested(let owners, _) = VerdictBuilder.build(evidence) else {
            return XCTFail("설정 주장은 시스템과 충돌한다")
        }
        XCTAssertEqual(owners, [inputSource, maccyPreview])
    }

    /// 관찰만 있고 주장이 없으면 여전히 소유자를 추정한다(미지 앱 탐지 경로).
    func testObservationAloneStillYieldsLikely() {
        let unknown = Owner.app(bundleID: "com.example.Unknown", name: "Unknown", action: nil)
        let evidence = [Evidence(source: .reaction, owner: unknown, confidence: .high,
                     reason: .systemHotkey(id: 0, combo: "-"), kind: .observation)]
        guard case .likely(let o, _) = VerdictBuilder.build(evidence) else {
            return XCTFail("관찰만 있어도 반응한 앱을 소유자로 추정해야 한다")
        }
        XCTAssertEqual(o, unknown)
    }

    /// 표시 문구는 App 계층이 언어별로 만든다. Engine은 구성 요소만 노출한다.
    func testOwnerExposesPartsForPresentation() {
        XCTAssertEqual(sys.parts.feature, "영역 스크린샷")
        XCTAssertNil(sys.parts.appName)
        XCTAssertEqual(rect.parts.appName, "Rectangle")
        XCTAssertEqual(rect.parts.action, "왼쪽 절반")
        XCTAssertNil(ray.parts.action)
    }
}
