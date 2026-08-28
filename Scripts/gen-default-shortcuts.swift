#!/usr/bin/env swift
// macOS가 제공하는 DefaultShortcutsTable.xml에서 Swift 폴백 테이블을 생성한다.
//
// 왜 생성하는가: 이 표를 손으로 유지하면 틀린다. 실제로 v2까지 손으로 만든 표에
// 잘못된 항목 4개(ID 7/57/59/175)와 누락 22개가 있었고, 그대로 certain 오판을 냈다.
// 앱은 런타임에 시스템 XML을 직접 읽고, 그 파일이 없을 때만 이 생성 결과로 폴백한다.
//
// 사용법:  swift Scripts/gen-default-shortcuts.swift > Sources/Engine/Resolvers/GeneratedShortcutTable.swift

import Foundation

let systemPath = "/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex"
    + "/Contents/Resources/en.lproj/DefaultShortcutsTable.xml"

guard let data = FileManager.default.contents(atPath: systemPath),
      let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
    FileHandle.standardError.write("에러: 시스템 표를 읽지 못했습니다 — \(systemPath)\n".data(using: .utf8)!)
    exit(1)
}

struct Row {
    let id: Int, name: String, keyCode: Int?, modifier: UInt64, enabled: Bool
}

var rows: [Row] = []
func walk(_ elements: [[String: Any]]) {
    for e in elements {
        if let id = e["sybmolichotkey"] as? Int {   // Apple의 오타를 그대로 따른다
            let raw = (e["name"] as? String) ?? ""
            let name = raw.replacingOccurrences(of: "DO_NOT_LOCALIZE: ", with: "")
            let key = e["key"] as? Int
            rows.append(Row(id: id,
                            name: name,
                            keyCode: (key == 65535) ? nil : key,   // 65535 = 키 없음
                            modifier: (e["modifier"] as? NSNumber)?.uint64Value ?? 0,
                            enabled: (e["enabled"] as? Bool) ?? true))
        }
        if let nested = e["elements"] as? [[String: Any]] { walk(nested) }
    }
}
for group in root { walk((group["elements"] as? [[String: Any]]) ?? []) }

let unique = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    .values.sorted { $0.id < $1.id }

var out = """
// 이 파일은 생성되었습니다 — 직접 수정하지 마세요.
// 생성: Scripts/gen-default-shortcuts.swift
// 출처: \(systemPath)
// 생성 시점 macOS의 표를 담은 폴백입니다. 앱은 런타임에 시스템 표를 우선 읽습니다.

import Foundation

enum GeneratedShortcutTable {
    /// (ID, 영문명, keyCode(nil = 키 없음), modifier 마스크, 기본 활성)
    static let rows: [(id: Int, name: String, keyCode: UInt16?, modifier: UInt64, enabled: Bool)] = [

"""
for r in unique {
    let kc = r.keyCode.map { "\($0)" } ?? "nil"
    let escaped = r.name.replacingOccurrences(of: "\"", with: "\\\"")
    out += "        (\(r.id), \"\(escaped)\", \(kc), \(r.modifier), \(r.enabled)),\n"
}
out += """
    ]
}

"""
print(out, terminator: "")
FileHandle.standardError.write("생성됨: \(unique.count)개 항목\n".data(using: .utf8)!)
