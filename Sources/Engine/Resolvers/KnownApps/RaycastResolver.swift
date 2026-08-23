import Foundation

extension KnownApps {
    /// 형식 "Command-Shift-49": 수정자 토큰들 + 마지막 정수 keyCode. 확인 전 가정 — 스펙 13절.
    public static let raycast = KnownAppDescriptor(
        bundleID: "com.raycast.macos", name: "Raycast",
        defaultFileURL: prefs.appendingPathComponent("com.raycast.macos.plist")
    ) { root in
        guard let s = root["raycastGlobalHotkey"] as? String, let combo = parseRaycast(s) else { return [] }
        return [(action: "호출", combo: combo)]
    }

    static func parseRaycast(_ s: String) -> KeyCombo? {
        var parts = s.split(separator: "-").map(String.init)
        guard let last = parts.popLast(), let key = UInt16(last) else { return nil }
        var m: Modifiers = []
        for p in parts {
            switch p {
            case "Command": m.insert(.command)
            case "Shift": m.insert(.shift)
            case "Option": m.insert(.option)
            case "Control": m.insert(.control)
            default: return nil
            }
        }
        return KeyCombo(keyCode: key, modifiers: m)
    }
}
