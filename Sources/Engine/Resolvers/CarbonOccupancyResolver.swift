import Foundation
import os

public struct CarbonOccupancyResolver: Resolver {
    
    let registrar: HotKeyRegistrar
    private static let log = Logger(subsystem: "HotkeyDetective", category: "carbon")

    public init(registrar: HotKeyRegistrar) { self.registrar = registrar }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        switch registrar.tryRegister(combo) {
        case .occupied:
            return [Evidence(source: .carbonProbe, owner: nil, confidence: .high,
                             reason: .carbonOccupied(combo: combo.display),
                             kind: .observation)]
        case .registeredAndReleased:
            return []
        case .error(let code):
            Self.log.debug("RegisterEventHotKey error \(code)")
            return []
        }
    }
}
