import Foundation

extension KnownApps {
    /// 형식 "Command-Shift-49": 수정자 토큰들 + 마지막 정수 keyCode.
    ///
    /// **미검증.** 키 이름과 값 형식 모두 실물로 확인한 적이 없다(2026-09-07 재확인:
    /// 온보딩을 마치지 않은 Raycast는 핫키를 기록하지 않아 여전히 확인 불가). 관찰된
    /// Raycast의 키 이름 규칙은 `raycast_AnonymousId`처럼 밑줄을 쓰는데 여기서 찾는
    /// `raycastGlobalHotkey`는 그렇지 않아, 이름이 틀렸을 가능성이 있다.
    ///
    /// 틀렸을 때의 결과는 오답이 아니라 조용한 누락이다 — 키를 못 찾으면 아무것도 내지
    /// 않고, 판정은 반응 감지로 떨어진다. 그래서 지우지 않고 남겨두되 여기 적어둔다.
    public static let raycast = KnownAppDescriptor(
        bundleID: "com.raycast.macos", name: "Raycast",
        defaultFileURL: prefs.appendingPathComponent("com.raycast.macos.plist")
    ) { root in
        guard let s = root["raycastGlobalHotkey"] as? String, let combo = parseRaycast(s) else { return [] }
        // Engine은 표시 문구를 만들지 않는다. Maccy·Rectangle과 마찬가지로 앱 자신의
        // 키 이름을 그대로 낸다 — 여기 한국어를 넣으면 14개 언어에서 한국어가 새어 나온다.
        return [(action: "globalHotkey", combo: combo)]
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
