import Foundation
import os

/// Karabiner-Elements — 키 리매퍼. 다른 어떤 출처도 볼 수 없는 자리에서 키를 가로챈다.
///
/// HID 드라이버 수준에서 동작하므로 가로챈 조합은 시스템 표에도 없고, 앱에 도달하지 않아
/// 반응도 없다. README가 "점유됐지만 식별 불가"로 인정한 사각지대가 정확히 이 경우다.
/// 설정은 `~/.config/karabiner/karabiner.json` — 손으로 고치도록 설계된 문서화된 JSON이다.
///
/// 실측(2026-09-10, Karabiner 15.x): 선택된 프로필 하나가 유효하고, 가로채는 조합은
///   - `complex_modifications.rules[].manipulators[].from` = key_code + modifiers.mandatory
///   - `simple_modifications[]` / `fn_function_keys[]` = from.key_code → to (항등이면 무의미)
/// 코어 서비스는 root 데몬이라 로그인 세션에서 보이지 않는다 — 활성 여부는 주입받는다.
public struct KarabinerResolver: Resolver, Enumerable {
    public static let bundleID = "org.pqrs.Karabiner-Elements.Settings"   // 사용자가 여는 앱
    public static let name = "Karabiner-Elements"
    public static let defaultConfigURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/karabiner/karabiner.json")

    let configURL: URL
    let isActive: () -> Bool
    private static let log = Logger(subsystem: "HotkeyDetective", category: "karabiner")

    public init(configURL: URL = KarabinerResolver.defaultConfigURL, isActive: @escaping () -> Bool) {
        self.configURL = configURL
        self.isActive = isActive
    }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        allPairs().filter { $0.0 == combo }.map { $0.1 }
    }

    public func allPairs() -> [(KeyCombo, Evidence)] {
        guard let data = try? Data(contentsOf: configURL),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let profile = Self.selectedProfile(root) else {
            Self.log.debug("설정 없음/파싱 실패 \(configURL.path)")
            return []
        }
        let active = isActive()
        return Self.hits(in: profile).map { hit in
            (hit.combo, Evidence(source: .keyRemap(appName: Self.name),
                owner: .app(bundleID: Self.bundleID, name: Self.name, action: hit.action),
                confidence: active ? .high : .low,
                reason: .remap(app: Self.name, rule: hit.action,
                               combo: hit.combo.display, isActive: active)))
        }
    }

    // MARK: 파싱

    static func selectedProfile(_ root: [String: Any]) -> [String: Any]? {
        guard let profiles = root["profiles"] as? [[String: Any]], !profiles.isEmpty else { return nil }
        return profiles.first { $0["selected"] as? Bool == true } ?? profiles[0]
    }

    /// 프로필이 가로채는 (액션, 조합) 목록. 결정적 순서.
    static func hits(in profile: [String: Any]) -> [(action: String, combo: KeyCombo)] {
        var out: [(action: String, combo: KeyCombo)] = []

        if let cm = profile["complex_modifications"] as? [String: Any],
           let rules = cm["rules"] as? [[String: Any]] {
            for (i, rule) in rules.enumerated() {
                let desc = (rule["description"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let action = desc.isEmpty ? "rule \(i + 1)" : desc
                for m in rule["manipulators"] as? [[String: Any]] ?? [] {
                    guard (m["type"] as? String ?? "basic") == "basic",
                          let from = m["from"] as? [String: Any],
                          let combo = combo(from: from) else { continue }
                    out.append((action, combo))
                }
            }
        }

        // 프로필 수준과 기기별 단순 매핑. 항등 매핑(f1 → f1)은 동작을 바꾸지 않으므로 뺀다.
        var simple = (profile["simple_modifications"] as? [[String: Any]] ?? [])
                   + (profile["fn_function_keys"] as? [[String: Any]] ?? [])
        for device in profile["devices"] as? [[String: Any]] ?? [] {
            simple += (device["simple_modifications"] as? [[String: Any]] ?? [])
                    + (device["fn_function_keys"] as? [[String: Any]] ?? [])
        }
        for entry in simple {
            guard let from = entry["from"] as? [String: Any],
                  let fromName = from["key_code"] as? String,
                  let code = KarabinerKeyNames.keyCode(for: fromName) else { continue }
            let toName = ((entry["to"] as? [[String: Any]])?.first?["key_code"] as? String) ?? ""
            if toName == fromName { continue }
            let to = toName == "vk_none" ? "(disabled)" : (toName.isEmpty ? "?" : toName)
            out.append(("\(fromName) → \(to)", KeyCombo(keyCode: code, modifiers: [])))
        }

        return out.sorted {
            if $0.action != $1.action { return $0.action < $1.action }
            if $0.combo.keyCode != $1.combo.keyCode { return $0.combo.keyCode < $1.combo.keyCode }
            return $0.combo.modifiers.rawValue < $1.combo.modifiers.rawValue
        }
    }

    /// manipulator의 `from`을 조합으로. 키 이름을 모르거나 수정자에 `any`가 있으면 nil —
    /// `any`는 그 키의 모든 조합을 뜻해 하나의 조합으로 표현할 수 없다.
    static func combo(from: [String: Any]) -> KeyCombo? {
        guard let name = from["key_code"] as? String,
              let code = KarabinerKeyNames.keyCode(for: name) else { return nil }
        var mods: Modifiers = []
        let mandatory = (from["modifiers"] as? [String: Any])?["mandatory"] as? [String] ?? []
        for m in mandatory {
            guard let bit = KarabinerKeyNames.modifier(for: m) else { return nil }
            mods.insert(bit)
        }
        return KeyCombo(keyCode: code, modifiers: mods)
    }
}

/// Karabiner의 키 이름(HID 사용법 이름) → 가상 키코드. US 레이아웃, KeyCodeNames와 같은 기준.
/// 이름 목록의 출처는 Karabiner-Elements.app/Contents/Resources/simple_modifications.json.
public enum KarabinerKeyNames {
    static let named: [String: UInt16] = [
        "spacebar": 49, "return_or_enter": 36, "tab": 48, "delete_or_backspace": 51, "escape": 53,
        "grave_accent_and_tilde": 50, "hyphen": 27, "equal_sign": 24, "open_bracket": 33,
        "close_bracket": 30, "backslash": 42, "semicolon": 41, "quote": 39, "comma": 43,
        "period": 47, "slash": 44, "caps_lock": 57,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111, "f13": 105, "f14": 107, "f15": 113,
        // F16–F20: Apple 확장 키보드에 있고, caps_lock → f19 같은 "하이퍼 키" 설정의 단골이다.
        "f16": 106, "f17": 64, "f18": 79, "f19": 80, "f20": 90,
        "home": 115, "end": 119, "page_up": 116, "page_down": 121, "delete_forward": 117,
        "left_arrow": 123, "right_arrow": 124, "up_arrow": 126, "down_arrow": 125,
    ]

    /// 문자·숫자는 KeyCodeNames 표를 뒤집어 얻는다 — 한 곳만 유지하기 위해서다.
    static let letters: [String: UInt16] = {
        var m: [String: UInt16] = [:]
        for (code, label) in KeyCodeNames.table where label.count == 1 {
            let c = label.first!
            if c.isLetter || c.isNumber { m[label.lowercased()] = code }
        }
        return m
    }()

    public static func keyCode(for name: String) -> UInt16? {
        named[name] ?? letters[name]
    }

    /// 좌우 구분은 버린다 — 조합의 정체성에 좌우는 없다. `any`·`caps_lock`은 표현 불가.
    public static func modifier(for name: String) -> Modifiers? {
        switch name {
        case "command", "left_command", "right_command": return .command
        case "shift", "left_shift", "right_shift": return .shift
        case "option", "left_option", "right_option": return .option
        case "control", "left_control", "right_control": return .control
        case "fn": return .function
        default: return nil
        }
    }
}
