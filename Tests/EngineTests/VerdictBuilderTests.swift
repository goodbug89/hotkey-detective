import XCTest
@testable import Engine

final class VerdictBuilderTests: XCTestCase {
    let sys = Owner.system(feature: "영역 스크린샷")
    let ray = Owner.app(bundleID: "com.raycast.macos", name: "Raycast", action: nil)
    let rect = Owner.app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: "왼쪽 절반")

    func ev(_ owner: Owner?, _ c: Confidence, src: String = "t") -> Evidence {
        Evidence(source: src, owner: owner, confidence: c, rationale: "r")
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

    func testOwnerDisplayName() {
        XCTAssertEqual(sys.displayName, "영역 스크린샷 (시스템)")
        XCTAssertEqual(rect.displayName, "Rectangle · 왼쪽 절반")
        XCTAssertEqual(ray.displayName, "Raycast")
    }
}
