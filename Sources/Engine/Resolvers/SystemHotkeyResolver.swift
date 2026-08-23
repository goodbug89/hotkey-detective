import Foundation

public struct SystemHotkeyResolver: Resolver {
    public let name = "시스템 단축키"
    let plistURL: URL

    public init(plistURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")) {
        self.plistURL = plistURL
    }

    struct Entry { let id: Int; let enabled: Bool; let combo: KeyCombo? }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        effectiveEntries().compactMap { e in
            guard e.enabled, e.combo == combo else { return nil }
            return Evidence(source: name, owner: .system(feature: SymbolicHotKeyDefaults.feature(for: e.id)),
                            confidence: .certain,
                            rationale: "symbolichotkeys 항목 \(e.id)이(가) \(combo.display)으로 활성화됨")
        }
    }

    /// 기본값 테이블 위에 plist 내용을 덮어쓴 최종 상태
    func effectiveEntries() -> [Entry] {
        var map: [Int: Entry] = [:]
        for (id, d) in SymbolicHotKeyDefaults.entries {
            map[id] = Entry(id: id, enabled: d.defaultEnabled, combo: d.combo)
        }
        for (id, raw) in loadPlist() {
            let enabled = raw["enabled"] as? Bool ?? true
            var combo = map[id]?.combo
            if let value = raw["value"] as? [String: Any],
               let p = value["parameters"] as? [Any], p.count == 3,
               let key = (p[1] as? NSNumber)?.uint16Value, let mask = (p[2] as? NSNumber)?.uint64Value,
               key != 65535 {
                combo = KeyCombo(keyCode: key, modifiers: Modifiers(cgFlags: mask))
            }
            map[id] = Entry(id: id, enabled: enabled, combo: combo)
        }
        return map.values.sorted { $0.id < $1.id }   // 증거 순서를 결정적으로 유지
    }

    private func loadPlist() -> [Int: [String: Any]] {
        guard let data = try? Data(contentsOf: plistURL),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let hot = root["AppleSymbolicHotKeys"] as? [String: [String: Any]] else { return [:] }
        var out: [Int: [String: Any]] = [:]
        for (k, v) in hot { if let id = Int(k) { out[id] = v } }
        return out
    }
}
