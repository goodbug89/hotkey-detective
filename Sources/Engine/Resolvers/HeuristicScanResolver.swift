import Foundation
import os

public struct ScannableApp: Hashable {
    public let bundleID: String
    public let name: String
    public let plistURLs: [URL]
    public init(bundleID: String, name: String, plistURLs: [URL]) {
        self.bundleID = bundleID; self.name = name; self.plistURLs = plistURLs
    }
    /// 존재하는 첫 plist
    var firstExisting: URL? { plistURLs.first { FileManager.default.fileExists(atPath: $0.path) } }
}

/// 실행 중 앱의 plist를 훑어 알려진 두 직렬화 패턴으로 단축키를 추정한다.
public struct HeuristicScanResolver: Resolver, Enumerable {
    public let name = "설정 스캔"
    let apps: [ScannableApp]
    let excludedBundleIDs: Set<String>
    private static let log = Logger(subsystem: "HotkeyDetective", category: "scan")

    public init(apps: [ScannableApp], excludedBundleIDs: Set<String>) {
        self.apps = apps; self.excludedBundleIDs = excludedBundleIDs
    }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        scanPairs { $0 == combo }.map { $0.1 }
    }

    public func allPairs() -> [(KeyCombo, Evidence)] {
        scanPairs { _ in true }
    }

    /// 정렬 키: (앱 인덱스, 액션, keyCode, modifiers). rationale 문자열이 아닌 이 4중 키로 정렬해야
    /// Dictionary 순회 순서(프로세스마다 해시 시드가 달라짐)에 기대지 않는 결정적 출력이 된다.
    private struct ScannedItem {
        let appIndex: Int
        let action: String
        let combo: KeyCombo
        let evidence: Evidence
    }

    private func scanPairs(_ include: (KeyCombo) -> Bool) -> [(KeyCombo, Evidence)] {
        var items: [ScannedItem] = []
        for (appIndex, app) in apps.enumerated() where !excludedBundleIDs.contains(app.bundleID) {
            guard let url = app.firstExisting,
                  let data = try? Data(contentsOf: url),
                  let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
                Self.log.debug("scan: 건너뜀 \(app.bundleID)")
                continue
            }
            for (action, combo) in extract(root) where include(combo) {
                items.append(ScannedItem(appIndex: appIndex, action: action, combo: combo,
                    evidence: Evidence(source: name,
                        owner: .app(bundleID: app.bundleID, name: app.name, action: action),
                        confidence: .medium,
                        rationale: "\(app.name) 설정에서 '\(action)' = \(combo.display) 패턴 발견")))
            }
        }
        items.sort { a, b in
            if a.appIndex != b.appIndex { return a.appIndex < b.appIndex }
            if a.action != b.action { return a.action < b.action }
            if a.combo.keyCode != b.combo.keyCode { return a.combo.keyCode < b.combo.keyCode }
            return a.combo.modifiers.rawValue < b.combo.modifiers.rawValue
        }
        return items.map { ($0.combo, $0.evidence) }
    }

    /// plist 재귀 순회 → (액션, 조합) 목록. 두 패턴만 인식.
    private func extract(_ any: Any, key: String = "") -> [(action: String, combo: KeyCombo)] {
        var found: [(String, KeyCombo)] = []
        if let dict = any as? [String: Any] {
            // MAS 패턴: keyCode + modifierFlags|modifierMask (CG 비트)
            if let k = (dict["keyCode"] as? NSNumber)?.uint16Value,
               let m = ((dict["modifierFlags"] ?? dict["modifierMask"]) as? NSNumber)?.uint64Value {
                found.append((key, KeyCombo(keyCode: k, modifiers: Modifiers(cgFlags: m))))
            }
            for (k, v) in dict {
                // KeyboardShortcuts 패턴: 접두어 키 + JSON 문자열 (Carbon 비트)
                if k.hasPrefix("KeyboardShortcuts_"), let s = v as? String,
                   let d = s.data(using: .utf8),
                   let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                   let kc = (j["carbonKeyCode"] as? NSNumber)?.uint16Value,
                   let cm = (j["carbonModifiers"] as? NSNumber)?.uint32Value {
                    found.append((String(k.dropFirst("KeyboardShortcuts_".count)),
                                  KeyCombo(keyCode: kc, modifiers: Modifiers(carbon: cm))))
                } else {
                    found.append(contentsOf: extract(v, key: k))
                }
            }
        } else if let arr = any as? [Any] {
            for v in arr { found.append(contentsOf: extract(v, key: key)) }
        }
        return found
    }
}
