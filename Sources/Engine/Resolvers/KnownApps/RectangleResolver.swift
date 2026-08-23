import Foundation

extension KnownApps {
    public static let rectangle = KnownAppDescriptor(
        bundleID: "com.knollsoft.Rectangle", name: "Rectangle",
        defaultFileURL: prefs.appendingPathComponent("com.knollsoft.Rectangle.plist")
    ) { root in
        root.compactMap { key, value in
            guard let d = value as? [String: Any],
                  let k = (d["keyCode"] as? NSNumber)?.uint16Value,
                  let m = (d["modifierFlags"] as? NSNumber)?.uint64Value else { return nil }
            return (action: key, combo: KeyCombo(keyCode: k, modifiers: Modifiers(cgFlags: m)))
        }
        .sorted { $0.action < $1.action }   // plist 딕셔너리 순서는 비결정적
    }
}
