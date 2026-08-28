import Foundation

public struct ReactionResolver: Resolver {
    public static let excludedBundleIDs: Set<String> = [
        "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.loginwindow", "com.apple.WindowManager",
    ]
    public init() {}

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        guard let p = probe else { return [] }
        var signals: [pid_t: [EvidenceReason.ReactionSignal]] = [:]

        for (pid, afterWins) in p.after.windows {
            let newWins = afterWins.subtracting(p.before.windows[pid] ?? [])
            if !newWins.isEmpty { signals[pid, default: []].append(.newWindows(count: newWins.count)) }
        }
        if let f = p.after.frontmostPID, f != p.before.frontmostPID {
            signals[f, default: []].append(.becameFrontmost)
        }

        // 신원을 알 수 없는 pid(WindowServer 등)는 증거로 만들 수 없으므로 개수 계산 전에 걸러낸다.
        // 그러지 않으면 이런 pid가 반응 앱 수를 부풀려 유일한 진짜 앱의 신뢰도를 medium으로 낮춘다.
        let reacting = signals.keys.filter { p.after.apps[$0] != nil && !isExcluded($0, p) }.sorted()
        let confidence: Confidence = reacting.count == 1 ? .high : .medium

        return reacting.map { pid in
            let app = p.after.apps[pid]!
            return Evidence(source: .reaction,
                            owner: .app(bundleID: app.bundleID ?? "pid:\(pid)", name: app.name, action: nil),
                            confidence: confidence,
                            reason: .reaction(app: app.name,
                                              milliseconds: Int(p.elapsed * 1000),
                                              signals: signals[pid]!),
                            kind: .observation)
        }
    }

    private func isExcluded(_ pid: pid_t, _ p: ProbeSnapshot) -> Bool {
        if pid == p.selfPID { return true }
        guard let bid = p.after.apps[pid]?.bundleID else { return false }
        return Self.excludedBundleIDs.contains(bid)
    }
}
