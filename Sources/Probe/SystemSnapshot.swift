import AppKit
import CoreGraphics
import Engine

public enum SystemSnapshot {
    public static func capture() -> SystemState {
        var windows: [pid_t: Set<UInt32>] = [:]
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard let pid = (w[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                      let wid = (w[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                      let layer = (w[kCGWindowLayer as String] as? NSNumber)?.intValue,
                      layer >= 0 else { continue }
                windows[pid, default: []].insert(wid)
            }
        }
        var apps: [pid_t: AppIdentity] = [:]
        for a in NSWorkspace.shared.runningApplications {
            apps[a.processIdentifier] = AppIdentity(bundleID: a.bundleIdentifier, name: a.localizedName ?? "pid \(a.processIdentifier)")
        }
        return SystemState(windows: windows,
                           frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                           apps: apps)
    }
}
