import Foundation

public enum RegistrationResult: Equatable {
    case registeredAndReleased
    case occupied          // eventHotKeyExistsErr (-9878)
    case error(Int32)
}

public protocol HotKeyRegistrar {
    func tryRegister(_ combo: KeyCombo) -> RegistrationResult
}
