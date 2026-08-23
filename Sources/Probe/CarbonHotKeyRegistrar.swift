import Carbon
import Engine

public struct CarbonHotKeyRegistrar: HotKeyRegistrar {
    public init() {}

    public func tryRegister(_ combo: KeyCombo) -> RegistrationResult {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x48444554) /* 'HDET' */, id: 1)
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.carbon, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            if let r = ref { UnregisterEventHotKey(r) }
            return .registeredAndReleased
        }
        if status == OSStatus(eventHotKeyExistsErr) { return .occupied }   // -9878
        return .error(status)
    }
}
