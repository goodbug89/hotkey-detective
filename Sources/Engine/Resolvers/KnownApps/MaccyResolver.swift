import Foundation

extension KnownApps {
    public static let maccy = KnownAppDescriptor(
        bundleID: "org.p0deje.Maccy", name: "Maccy",
        // Maccy 2.x는 샌드박스 앱 — 컨테이너 경로가 우선 (2026-08-23 실측, brew cask 2.x)
        candidateFileURLs: [containerPrefs("org.p0deje.Maccy"), prefs.appendingPathComponent("org.p0deje.Maccy.plist")]
    ) { root in
        root.compactMap { key, value in
            guard key.hasPrefix("KeyboardShortcuts_"), let s = value as? String,
                  let data = s.data(using: .utf8),
                  let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let k = (j["carbonKeyCode"] as? NSNumber)?.uint16Value,
                  let m = (j["carbonModifiers"] as? NSNumber)?.uint32Value else { return nil }
            return (action: String(key.dropFirst("KeyboardShortcuts_".count)),
                    combo: KeyCombo(keyCode: k, modifiers: Modifiers(carbon: m)))
        }
        .sorted { $0.action < $1.action }   // plist 딕셔너리 순서는 비결정적
    }
}
