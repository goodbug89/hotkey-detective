import Foundation
import Engine
import SwiftUI

/// 표시 문구를 한곳에서 만든다.
///
/// Engine은 사실만 담고(`EvidenceReason`), 문장 조립은 여기서 언어별로 한다.
/// 문자열은 `Resources/<lang>.lproj/Localizable.strings`에서 온다.
enum L {
    static func t(_ key: String, _ args: CVarArg...) -> String {
        let format = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        return args.isEmpty ? format : String(format: format, arguments: args)
    }

    /// 번역이 있으면 쓰고, 없으면 원문을 그대로 돌려준다.
    /// 시스템 기능명처럼 일부 언어에만 번역이 있는 문자열에 쓴다.
    ///
    /// `value`를 빈 문자열로 주면 Foundation이 **키 자체**를 돌려주므로("feature.Save…"가
    /// 그대로 화면에 나온다) 충돌할 수 없는 센티널을 넘겨 없음을 판별한다.
    static func optional(_ key: String, fallback: String) -> String {
        let sentinel = "\u{0}"
        let t = Bundle.module.localizedString(forKey: key, value: sentinel, table: nil)
        return t == sentinel ? fallback : t
    }
}

extension EvidenceSource {
    /// 뱃지 라벨. 문자열 매칭이 아니라 케이스로 고르므로 어떤 언어에서도 깨지지 않는다.
    var badgeLabel: String {
        switch self {
        case .systemHotkeys: return L.t("badge.system")
        case .knownAppParser: return L.t("badge.parser")
        case .heuristicScan: return L.t("badge.scan")
        case .reaction: return L.t("badge.reaction")
        case .carbonProbe: return L.t("badge.probe")
        }
    }

    /// 강한 근거(시스템·파서)는 강조색, 약하거나 관찰인 것은 중립색.
    var badgeTint: Color {
        switch self {
        case .systemHotkeys, .knownAppParser: return .accentColor
        case .heuristicScan, .reaction, .carbonProbe: return .secondary
        }
    }
}

extension Owner {
    /// 소유자 표시 문구. 시스템/앱/액션 조합을 언어별 포맷으로 만든다.
    var displayName: String {
        let p = parts
        if let feature = p.feature {
            // 기능명은 macOS가 영어로만 주고, 번역은 한국어 카탈로그에만 있다.
            // 다른 언어는 영어 원문으로 떨어져 시스템 설정과 표현이 어긋나지 않는다.
            return L.t("owner.system", L.optional("feature.\(feature)", fallback: feature))
        }
        let name = p.appName ?? ""
        if let action = p.action { return L.t("owner.appAction", name, action) }
        return name
    }
}

extension EvidenceReason {
    /// 근거 한 줄. 언어마다 어순과 조사가 다르므로 포맷 문자열에 값을 넣는 방식으로만 조립한다.
    var localizedText: String {
        switch self {
        case .systemHotkey(let id, let combo):
            return L.t("reason.systemHotkey", String(id), combo)

        case .knownApp(let app, let action, let combo, let isRunning):
            return isRunning
                ? L.t("reason.knownApp", app, action, combo)
                : L.t("reason.knownApp.notRunning", app, action, combo)

        case .scanPattern(let app, let action, let combo):
            return action.map { L.t("reason.scanPattern", app, $0, combo) }
                ?? L.t("reason.scanPattern.noAction", app, combo)

        case .reaction(let app, let ms, let signals):
            let detail = signals.map(\.localizedText).joined(separator: L.t("reason.signalSeparator"))
            return L.t("reason.reaction", String(ms), app, detail)

        case .carbonOccupied(let combo):
            return L.t("reason.carbonOccupied", combo)
        }
    }
}

extension EvidenceReason.ReactionSignal {
    var localizedText: String {
        switch self {
        case .newWindows(let count): return L.t("signal.newWindows", String(count))
        case .becameFrontmost: return L.t("signal.becameFrontmost")
        }
    }
}
