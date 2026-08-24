import AppKit
import Engine

public enum RunningAppsProvider {
    /// 실행 중인 모든 앱(백그라운드 에이전트 포함)을 스캔 대상으로. bundleID별 일반+컨테이너 plist 경로.
    public static func scannableApps() -> [ScannableApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bid = app.bundleIdentifier, let name = app.localizedName else { return nil }
            let prefs = home.appendingPathComponent("Library/Preferences/\(bid).plist")
            let container = home.appendingPathComponent("Library/Containers/\(bid)/Data/Library/Preferences/\(bid).plist")
            return ScannableApp(bundleID: bid, name: name, plistURLs: [prefs, container])
        }
    }
}
