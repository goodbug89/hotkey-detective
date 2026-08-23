import Foundation

public struct AppIdentity: Hashable, Codable {
    public let bundleID: String?
    public let name: String
    public init(bundleID: String?, name: String) { self.bundleID = bundleID; self.name = name }
}

public struct SystemState {
    public let windows: [pid_t: Set<UInt32>]
    public let frontmostPID: pid_t?
    public let apps: [pid_t: AppIdentity]
    public init(windows: [pid_t: Set<UInt32>], frontmostPID: pid_t?, apps: [pid_t: AppIdentity]) {
        self.windows = windows; self.frontmostPID = frontmostPID; self.apps = apps
    }
}

public struct ProbeSnapshot {
    public let before: SystemState
    public let after: SystemState
    public let elapsed: TimeInterval
    public let selfPID: pid_t
    public init(before: SystemState, after: SystemState, elapsed: TimeInterval, selfPID: pid_t) {
        self.before = before; self.after = after; self.elapsed = elapsed; self.selfPID = selfPID
    }
}

public protocol Resolver {
    var name: String { get }
    /// probe == nil 이면 제한 모드(권한 없음). 스냅샷이 필요한 Resolver는 빈 배열을 반환한다.
    func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence]
}
