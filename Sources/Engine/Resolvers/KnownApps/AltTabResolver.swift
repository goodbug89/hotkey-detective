import Foundation

extension KnownApps {
    /// AltTab — 창 전환기. 단축키를 `holdShortcut<N>` / `nextWindowShortcut<N>` 같은 키에
    /// `{string, secureData}` 딕셔너리로 저장한다.
    ///
    /// `secureData`는 ShortcutRecorder `SRShortcut`을 NSKeyedArchiver로 담은 바이너리
    /// plist다. 클래스를 등록해 언아카이브하는 대신 `$objects`를 직접 걷는다 — Engine은
    /// AppKit에 의존하지 않고, 우리에게 필요한 건 정수 두 개뿐이다.
    ///
    /// 실측(2026-09-07, AltTab 11.6.0):
    ///   - `$objects[1]`에 keyCode·modifierFlags가 UID 참조로 들어 있다
    ///   - keyCode 65535는 "키 없음"(수정자만 쓰는 hold 트리거가 이 값을 쓴다)
    ///   - modifierFlags는 CG/NSEvent 비트다 (⌥ = 524288)
    ///   - keyCode 12·modifierFlags 524288을 주입하자 AltTab이 자기 설정 화면에 "⌥q"로
    ///     표시했다. 즉 표준 가상 키코드가 맞다.
    public static let altTab = KnownAppDescriptor(
        bundleID: "com.lwouis.alt-tab-macos", name: "AltTab",
        defaultFileURL: prefs.appendingPathComponent("com.lwouis.alt-tab-macos.plist")
    ) { root in
        root.compactMap { key, value -> (action: String, combo: KeyCombo)? in
            guard key.hasSuffix("Shortcut") || key.range(of: #"Shortcut\d+$"#, options: .regularExpression) != nil,
                  let dict = value as? [String: Any],
                  let data = dict["secureData"] as? Data,
                  let combo = parseAltTabShortcut(data) else { return nil }
            return (action: key, combo: combo)
        }
        .sorted { $0.action < $1.action }   // plist 딕셔너리 순서는 비결정적
    }

    /// 아카이브에서 keyCode·modifierFlags를 꺼낸다. 키가 없으면(65535) nil.
    ///
    /// `$objects`를 직접 걸으려 했으나 UID 참조가 Swift에서 `CFKeyedArchiverUID`로 와서
    /// 숫자로 읽을 수 없다(공개 접근자가 없다). 대신 아카이버에게 SRShortcut 자리에 우리
    /// 상자를 놓게 하고 정수 두 개만 받아온다 — 공개 API만 쓰는 길이다.
    static func parseAltTabShortcut(_ data: Data) -> KeyCombo? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(AltTabShortcutBox.self, forClassName: "SRShortcut")
        let box = unarchiver.decodeObject(of: AltTabShortcutBox.self, forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()
        guard let box, box.keyCode != 65535, box.keyCode >= 0, box.keyCode <= Int(UInt16.max) else { return nil }
        return KeyCombo(keyCode: UInt16(box.keyCode), modifiers: Modifiers(cgFlags: UInt64(box.modifierFlags)))
    }
}

/// SRShortcut 대신 세워두는 상자. 필요한 두 필드만 꺼내고 나머지는 무시한다.
/// (중첩 타입은 NSCoding에서 이름이 불안정해 최상위에 둔다.)
@objc(HDAltTabShortcutBox)
final class AltTabShortcutBox: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let keyCode: Int
    let modifierFlags: Int

    init(coder: NSCoder) {
        // SRShortcut은 두 값을 NSNumber 객체로 넣는다. decodeInteger는 primitive로 인코딩된
        // 값만 읽으므로 여기서는 항상 0을 돌려준다 — 객체로 꺼내야 한다.
        func number(_ key: String) -> Int {
            (coder.decodeObject(of: NSNumber.self, forKey: key))?.intValue
                ?? coder.decodeInteger(forKey: key)
        }
        keyCode = number("keyCode")
        modifierFlags = number("modifierFlags")
        super.init()
    }
    func encode(with coder: NSCoder) {}
}
