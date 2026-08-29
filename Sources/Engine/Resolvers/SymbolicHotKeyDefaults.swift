import Foundation
import os

/// symbolichotkeys ID → (표시명, 기본 조합, 기본 활성 여부).
///
/// 출처는 macOS가 제공하는 `DefaultShortcutsTable.xml`이다. 이 표를 손으로 유지하던
/// v1~v2에서는 잘못된 항목 4개(ID 7/57/59/175)와 누락 22개가 있었고 그대로 certain
/// 오판을 냈다. 이제 런타임에 시스템 표를 읽고, 없을 때만 생성된 폴백을 쓴다.
public enum SymbolicHotKeyDefaults {
    private static let log = Logger(subsystem: "HotkeyDetective", category: "defaults")

    /// macOS 키보드 설정 확장의 기본 단축키 표. 비공개 경로라 없을 수 있다.
    static let systemTableURL = URL(fileURLWithPath:
        "/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex"
        + "/Contents/Resources/en.lproj/DefaultShortcutsTable.xml")

    public struct Entry {
        public let id: Int
        public let feature: String
        public let combo: KeyCombo?
        public let defaultEnabled: Bool
    }

    /// 한 번만 계산한다. 시스템 표 → 실패 시 생성된 폴백.
    public static let all: [Entry] = load()

    public static let entries: [Int: (feature: String, combo: KeyCombo?, defaultEnabled: Bool)] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, ($0.feature, $0.combo, $0.defaultEnabled)) })

    /// 시스템 표에 없는 ID는 일반 이름으로 둔다. 이름은 시스템이 주는 영어 그대로이며,
    /// 언어별 번역은 App 계층(`Owner.displayName`)에서 붙인다 — Engine이 한국어 이름을
    /// 무조건 붙이던 때에는 영어 UI에서 "영역 스크린샷 저장 (system) is using this"처럼 섞였다.
    /// 사용자 plist에는 표에 없는 ID가 실제로 나타난다(이 머신 기준 10개: 16/18/20/22/24/34/80/82/164/176).
    /// 대부분 비활성이거나 키가 없어 증거를 만들지 않고, 남는 것도 이름만 일반화된다.
    /// 이름을 추측해 채우면 v1~v2에서 certain 오판을 냈던 실패로 되돌아가므로 하지 않는다.
    public static func feature(for id: Int) -> String {
        entries[id]?.feature ?? "System function #\(id)"
    }

    // MARK: - 적재

    static func load() -> [Entry] {
        if let rows = parseSystemTable(at: systemTableURL), !rows.isEmpty {
            log.debug("시스템 단축키 표 사용: \(rows.count)개")
            return rows.map(entry(from:))
        }
        log.debug("시스템 표 없음 — 생성된 폴백 사용")
        return GeneratedShortcutTable.rows
            .map { Row(id: $0.id, name: $0.name, keyCode: $0.keyCode, modifier: $0.modifier, enabled: $0.enabled) }
            .map(entry(from:))
    }

    struct Row {
        let id: Int, name: String, keyCode: UInt16?, modifier: UInt64, enabled: Bool
    }

    /// 시스템 XML을 파싱한다. 구조가 바뀌면 nil을 돌려 폴백으로 넘어간다.
    static func parseSystemTable(at url: URL) -> [Row]? {
        guard let data = try? Data(contentsOf: url),
              let groups = (try? PropertyListSerialization.propertyList(from: data, format: nil))
                as? [[String: Any]] else { return nil }
        var rows: [Row] = []
        func walk(_ elements: [[String: Any]]) {
            for e in elements {
                if let id = e["sybmolichotkey"] as? Int {   // Apple의 오타를 그대로 따른다
                    let raw = (e["name"] as? String) ?? ""
                    let key = e["key"] as? Int
                    rows.append(Row(id: id,
                                    name: raw.replacingOccurrences(of: "DO_NOT_LOCALIZE: ", with: ""),
                                    keyCode: (key == 65535 || key == nil) ? nil : UInt16(key!),
                                    modifier: (e["modifier"] as? NSNumber)?.uint64Value ?? 0,
                                    enabled: (e["enabled"] as? Bool) ?? true))
                }
                if let nested = e["elements"] as? [[String: Any]] { walk(nested) }
            }
        }
        for g in groups { walk((g["elements"] as? [[String: Any]]) ?? []) }
        var seen = Set<Int>()
        return rows.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }

    static func entry(from r: Row) -> Entry {
        Entry(id: r.id,
              feature: r.name,   // 시스템의 영문명. 번역은 표시 계층의 몫이다.
              combo: combo(keyCode: r.keyCode, modifier: r.modifier),
              defaultEnabled: r.enabled)
    }

    /// fn+화살표는 macOS가 키보드 단계에서 내비게이션 키로 바꿔 보내므로(fn+← = Home),
    /// 이벤트 탭이 보는 형태로 맞춰 저장한다. 그 외 fn 조합(fn+F 등)은 변환 대상이
    /// 없으므로 fn을 남겨둔다 — 남겨두면 탭의 조합과 절대 일치하지 않아
    /// 인벤토리에는 보이되 탐침에서 거짓 매칭을 만들지 않는다.
    static let fnArrowToNavigation: [UInt16: UInt16] = [
        123: 115,   // ← → Home
        124: 119,   // → → End
        126: 116,   // ↑ → Page Up
        125: 121,   // ↓ → Page Down
    ]

    static func combo(keyCode: UInt16?, modifier: UInt64) -> KeyCombo? {
        guard let keyCode else { return nil }
        var mods = Modifiers(tableMask: modifier)
        var key = keyCode
        if mods.contains(.function), let navKey = fnArrowToNavigation[keyCode] {
            key = navKey
            mods.remove(.function)
        }
        return KeyCombo(keyCode: key, modifiers: mods)
    }

}
