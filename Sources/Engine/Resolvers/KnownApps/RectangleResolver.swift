import Foundation

extension KnownApps {
    /// Rectangle은 기본 단축키를 plist에 쓰지 않는다 (2026-08-23 실측, v0.99).
    /// plist에는 `alternateDefaultShortcuts`(1 = "Recommended" 세트, 0/없음 = Spectacle 세트)와
    /// 사용자가 바꾼 액션만 `{keyCode, modifierFlags}`로 기록된다. 따라서 기본 테이블 위에
    /// plist 항목을 덮어쓰고, keyCode가 없는 항목(사용자가 해제한 단축키)은 제거한다.
    public static let rectangle = KnownAppDescriptor(
        bundleID: "com.knollsoft.Rectangle", name: "Rectangle",
        defaultFileURL: prefs.appendingPathComponent("com.knollsoft.Rectangle.plist")
    ) { root in
        let useRecommended = (root["alternateDefaultShortcuts"] as? NSNumber)?.boolValue ?? false
        var table = useRecommended ? rectangleRecommendedDefaults : rectangleSpectacleDefaults

        for (key, value) in root {
            guard let d = value as? [String: Any] else { continue }
            if let k = (d["keyCode"] as? NSNumber)?.uint16Value,
               let m = (d["modifierFlags"] as? NSNumber)?.uint64Value {
                table[key] = KeyCombo(keyCode: k, modifiers: Modifiers(cgFlags: m))
            } else {
                table[key] = nil   // 빈 dict = 단축키 해제
            }
        }
        return table.map { (action: $0.key, combo: $0.value) }.sorted { $0.action < $1.action }
    }

    static func rc(_ k: UInt16, _ m: Modifiers) -> KeyCombo { KeyCombo(keyCode: k, modifiers: m) }

    /// "Recommended" 세트 (alternateDefaultShortcuts = 1). ⌃⌥ 기반.
    static let rectangleRecommendedDefaults: [String: KeyCombo] = [
        "leftHalf": rc(123, [.control, .option]),
        "rightHalf": rc(124, [.control, .option]),
        "topHalf": rc(126, [.control, .option]),
        "bottomHalf": rc(125, [.control, .option]),
        "maximize": rc(36, [.control, .option]),
        "center": rc(8, [.control, .option]),
        "restore": rc(51, [.control, .option]),
        "topLeft": rc(32, [.control, .option]),
        "topRight": rc(34, [.control, .option]),
        "bottomLeft": rc(38, [.control, .option]),
        "bottomRight": rc(40, [.control, .option]),
        "larger": rc(24, [.control, .option]),
        "smaller": rc(27, [.control, .option]),
        "firstThird": rc(2, [.control, .option]),
        "centerThird": rc(3, [.control, .option]),
        "lastThird": rc(5, [.control, .option]),
        "firstTwoThirds": rc(14, [.control, .option]),
        "lastTwoThirds": rc(17, [.control, .option]),
        "maximizeHeight": rc(126, [.control, .option, .shift]),
        "nextDisplay": rc(124, [.control, .option, .command]),
        "previousDisplay": rc(123, [.control, .option, .command]),
    ]

    /// Spectacle 호환 세트 (alternateDefaultShortcuts = 0). ⌥⌘ 기반. 핵심 액션만 수록.
    static let rectangleSpectacleDefaults: [String: KeyCombo] = [
        "leftHalf": rc(123, [.option, .command]),
        "rightHalf": rc(124, [.option, .command]),
        "topHalf": rc(126, [.option, .command]),
        "bottomHalf": rc(125, [.option, .command]),
        "maximize": rc(3, [.option, .command]),
        "center": rc(8, [.option, .command]),
        "topLeft": rc(123, [.control, .command]),
        "topRight": rc(124, [.control, .command]),
        "bottomLeft": rc(123, [.control, .shift, .command]),
        "bottomRight": rc(124, [.control, .shift, .command]),
        "larger": rc(124, [.control, .option, .shift]),
        "smaller": rc(123, [.control, .option, .shift]),
        "nextDisplay": rc(124, [.control, .option, .command]),
        "previousDisplay": rc(123, [.control, .option, .command]),
    ]
}
