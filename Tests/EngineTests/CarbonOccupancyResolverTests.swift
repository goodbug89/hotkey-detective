import XCTest
@testable import Engine

final class CarbonOccupancyResolverTests: XCTestCase {
    struct Fake: HotKeyRegistrar {
        let result: RegistrationResult
        func tryRegister(_ combo: KeyCombo) -> RegistrationResult { result }
    }
    let combo = KeyCombo(keyCode: 49, modifiers: [.option])

    func testOccupiedYieldsHighEvidenceWithNilOwner() {
        let e = CarbonOccupancyResolver(registrar: Fake(result: .occupied)).resolve(combo, probe: nil)
        XCTAssertEqual(e.count, 1)
        XCTAssertNil(e[0].owner)
        XCTAssertEqual(e[0].confidence, .high)
    }

    func testFreeYieldsNothing() {
        XCTAssertTrue(CarbonOccupancyResolver(registrar: Fake(result: .registeredAndReleased)).resolve(combo, probe: nil).isEmpty)
    }

    func testErrorYieldsNothing() {
        XCTAssertTrue(CarbonOccupancyResolver(registrar: Fake(result: .error(-50))).resolve(combo, probe: nil).isEmpty)
    }
}
