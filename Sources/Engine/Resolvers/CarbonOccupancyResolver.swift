import Foundation
import os

public struct CarbonOccupancyResolver: Resolver {
    public let name = "핫키 등록 시도"
    let registrar: HotKeyRegistrar
    private static let log = Logger(subsystem: "HotkeyDetective", category: "carbon")

    public init(registrar: HotKeyRegistrar) { self.registrar = registrar }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        switch registrar.tryRegister(combo) {
        case .occupied:
            return [Evidence(source: name, owner: nil, confidence: .high,
                             rationale: "다른 프로세스가 \(combo.display)을(를) Carbon 핫키로 등록함")]
        case .registeredAndReleased:
            return []
        case .error(let code):
            Self.log.debug("RegisterEventHotKey error \(code)")
            return []
        }
    }
}
