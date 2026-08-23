import Foundation

public struct ReactionResolver: Resolver {
    public let name = "반응 감지"
    public static let excludedBundleIDs: Set<String> = [
        "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.loginwindow", "com.apple.WindowManager",
    ]
    public init() {}

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        guard let p = probe else { return [] }
        var reasons: [pid_t: [String]] = [:]

        for (pid, afterWins) in p.after.windows {
            let newWins = afterWins.subtracting(p.before.windows[pid] ?? [])
            if !newWins.isEmpty { reasons[pid, default: []].append("새 창 \(newWins.count)개 표시") }
        }
        if let f = p.after.frontmostPID, f != p.before.frontmostPID {
            reasons[f, default: []].append("활성 앱으로 전환됨")
        }

        let reacting = reasons.keys.filter { !isExcluded($0, p) }.sorted()
        let confidence: Confidence = reacting.count == 1 ? .high : .medium

        return reacting.compactMap { pid in
            guard let app = p.after.apps[pid] else { return nil }
            return Evidence(source: name,
                            owner: .app(bundleID: app.bundleID ?? "pid:\(pid)", name: app.name, action: nil),
                            confidence: confidence,
                            rationale: "\(combo.display) 입력 \(Int(p.elapsed * 1000))ms 후 \(app.name)이(가) " + reasons[pid]!.joined(separator: ", "))
        }
    }

    private func isExcluded(_ pid: pid_t, _ p: ProbeSnapshot) -> Bool {
        if pid == p.selfPID { return true }
        guard let bid = p.after.apps[pid]?.bundleID else { return false }
        return Self.excludedBundleIDs.contains(bid)
    }
}
