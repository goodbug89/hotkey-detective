import XCTest
@testable import Engine

final class ReactionResolverTests: XCTestCase {
    let combo = KeyCombo(keyCode: 49, modifiers: [.option])
    let me: pid_t = 100, ray: pid_t = 200, rect: pid_t = 300, dock: pid_t = 400
    var apps: [pid_t: AppIdentity] {
        [me: .init(bundleID: "dev.goodbug.HotkeyDetective", name: "HotkeyDetective"),
         ray: .init(bundleID: "com.raycast.macos", name: "Raycast"),
         rect: .init(bundleID: "com.knollsoft.Rectangle", name: "Rectangle"),
         dock: .init(bundleID: "com.apple.dock", name: "Dock")]
    }
    func snap(before: [pid_t: Set<UInt32>], after: [pid_t: Set<UInt32>], frontBefore: pid_t? = nil, frontAfter: pid_t? = nil) -> ProbeSnapshot {
        ProbeSnapshot(before: SystemState(windows: before, frontmostPID: frontBefore, apps: apps),
                      after: SystemState(windows: after, frontmostPID: frontAfter, apps: apps),
                      elapsed: 0.3, selfPID: me)
    }
    let r = ReactionResolver()

    func testNilProbeGivesNothing() {
        XCTAssertTrue(r.resolve(combo, probe: nil).isEmpty)
    }

    func testNewWindowFromOneAppIsHigh() {
        let e = r.resolve(combo, probe: snap(before: [ray: []], after: [ray: [1]]))
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].owner, .app(bundleID: "com.raycast.macos", name: "Raycast", action: nil))
        XCTAssertEqual(e[0].confidence, .high)
    }

    func testFrontmostChangeIsHigh() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [:], frontBefore: me, frontAfter: rect))
        XCTAssertEqual(e.first?.owner, .app(bundleID: "com.knollsoft.Rectangle", name: "Rectangle", action: nil))
        XCTAssertEqual(e.first?.confidence, .high)
    }

    func testNoChangeGivesNothing() {
        XCTAssertTrue(r.resolve(combo, probe: snap(before: [ray: [1]], after: [ray: [1]], frontBefore: me, frontAfter: me)).isEmpty)
    }

    func testSelfAndSystemProcessesExcluded() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [me: [5], dock: [6]], frontBefore: nil, frontAfter: dock))
        XCTAssertTrue(e.isEmpty)
    }

    func testTwoReactingAppsAreMediumEach() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [ray: [1], rect: [2]]))
        XCTAssertEqual(e.count, 2)
        XCTAssertTrue(e.allSatisfy { $0.confidence == .medium })
    }

    func testSameAppNewWindowAndFrontmostIsOneEvidence() {
        let e = r.resolve(combo, probe: snap(before: [:], after: [ray: [1]], frontBefore: me, frontAfter: ray))
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].confidence, .high)
    }
}
