import AppKit
import Engine

public struct WorkspaceRunningApps: RunningAppChecker {
    public init() {}
    public func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}
