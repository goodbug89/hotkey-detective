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

/// 탐침(특정 조합) 대신 이 Resolver가 아는 모든 단축키를 (조합, 증거) 페어로 낸다. 인벤토리용.
/// 조합을 함께 내는 이유: Evidence에는 조합이 없어 인벤토리가 조합별로 그룹핑할 수 없기 때문.
public protocol Enumerable {
    func allPairs() -> [(KeyCombo, Evidence)]
}
public extension Enumerable {
    func allEvidence() -> [Evidence] { allPairs().map(\.1) }
}
