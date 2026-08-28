import Foundation
import os

/// 스캔 대상 앱. 경로를 두 종류로 나눠 담는다 — 일반 Preferences 경로는 그냥 읽히지만,
/// 샌드박스 컨테이너 경로는 읽는 순간 macOS가 "다른 앱의 데이터에 접근" 권한을 묻는다.
/// 그래서 컨테이너 경로는 별도 필드에 두고, 명시적으로 허용한 스캔에서만 본다.
public struct ScannableApp: Hashable {
    public let bundleID: String
    public let name: String
    public let plistURLs: [URL]
    public let containerPlistURLs: [URL]
    public init(bundleID: String, name: String, plistURLs: [URL], containerPlistURLs: [URL]) {
        self.bundleID = bundleID; self.name = name
        self.plistURLs = plistURLs; self.containerPlistURLs = containerPlistURLs
    }
    public init(bundleID: String, name: String, plistURLs: [URL]) {
        self.init(bundleID: bundleID, name: name, plistURLs: plistURLs, containerPlistURLs: [])
    }
}

/// 실행 중 앱의 plist를 훑어 알려진 두 직렬화 패턴으로 단축키를 추정한다.
public struct HeuristicScanResolver: Resolver, Enumerable {
    
    let apps: [ScannableApp]
    let excludedBundleIDs: Set<String>
    /// 샌드박스 컨테이너 plist까지 읽을지. 켜면 앱마다 macOS TCC 권한 창이 뜰 수 있으므로
    /// 사용자가 명시적으로 요청한 "심층 스캔"에서만 true.
    let includeContainers: Bool
    private static let log = Logger(subsystem: "HotkeyDetective", category: "scan")

    public init(apps: [ScannableApp], excludedBundleIDs: Set<String>, includeContainers: Bool = false) {
        self.apps = apps; self.excludedBundleIDs = excludedBundleIDs
        self.includeContainers = includeContainers
    }

    /// 존재하는 첫 plist
    private func firstExisting(_ urls: [URL]) -> URL? {
        urls.first { FileManager.default.fileExists(atPath: $0.path) }
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
        let action: String?
        let combo: KeyCombo
        let evidence: Evidence
    }

    private func scanPairs(_ include: (KeyCombo) -> Bool) -> [(KeyCombo, Evidence)] {
        var items: [ScannedItem] = []
        for (appIndex, app) in apps.enumerated() where !excludedBundleIDs.contains(app.bundleID) {
            let urls = includeContainers ? app.plistURLs + app.containerPlistURLs : app.plistURLs
            guard let url = firstExisting(urls),
                  let data = try? Data(contentsOf: url),
                  let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
                Self.log.debug("scan: 건너뜀 \(app.bundleID)")
                continue
            }
            for (action, combo) in extract(root) where include(combo) {
                // 액션 이름이 없는(plist 루트에 놓인) 패턴은 따옴표만 남은 문구가 되지 않게 문장을 바꾼다.

                items.append(ScannedItem(appIndex: appIndex, action: action, combo: combo,
                    evidence: Evidence(source: .heuristicScan,
                        owner: .app(bundleID: app.bundleID, name: app.name, action: action),
                        confidence: .medium,
                        reason: .scanPattern(app: app.name, action: action, combo: combo.display))))
            }
        }
        items.sort { a, b in
            if a.appIndex != b.appIndex { return a.appIndex < b.appIndex }
            if a.action != b.action { return (a.action ?? "") < (b.action ?? "") }
            if a.combo.keyCode != b.combo.keyCode { return a.combo.keyCode < b.combo.keyCode }
            return a.combo.modifiers.rawValue < b.combo.modifiers.rawValue
        }
        return items.map { ($0.combo, $0.evidence) }
    }

    /// plist 재귀 순회 → (액션, 조합) 목록. 두 패턴만 인식.
    /// 액션은 옵셔널 — plist 루트에 바로 놓인 패턴에는 이름을 붙일 키가 없다.
    private func extract(_ any: Any, key: String = "") -> [(action: String?, combo: KeyCombo)] {
        var found: [(String?, KeyCombo)] = []
        if let dict = any as? [String: Any] {
            // MAS 패턴: keyCode + modifierFlags|modifierMask (CG 비트)
            if let k = (dict["keyCode"] as? NSNumber)?.uint16Value,
               let m = ((dict["modifierFlags"] ?? dict["modifierMask"]) as? NSNumber)?.uint64Value {
                found.append((key.isEmpty ? nil : key, KeyCombo(keyCode: k, modifiers: Modifiers(cgFlags: m))))
            }
            for (k, v) in dict {
                // KeyboardShortcuts 패턴: 접두어 키 + JSON 문자열 (Carbon 비트)
                if k.hasPrefix("KeyboardShortcuts_"), let s = v as? String,
                   let d = s.data(using: .utf8),
                   let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                   let kc = (j["carbonKeyCode"] as? NSNumber)?.uint16Value,
                   let cm = (j["carbonModifiers"] as? NSNumber)?.uint32Value {
                    let action = String(k.dropFirst("KeyboardShortcuts_".count))
                    found.append((action.isEmpty ? nil : action,
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
