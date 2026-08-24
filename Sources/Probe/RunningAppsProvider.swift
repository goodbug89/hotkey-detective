import AppKit
import Engine

public enum RunningAppsProvider {
    /// 실행 중인 모든 앱(백그라운드 에이전트 포함)을 스캔 대상으로.
    /// 일반 Preferences 경로와 샌드박스 컨테이너 경로를 나눠 담는다 — 후자는 읽는 순간
    /// macOS가 권한을 묻기 때문에 심층 스캔에서만 쓰인다.
    public static func scannableApps() -> [ScannableApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bid = app.bundleIdentifier, let name = app.localizedName else { return nil }
            let prefs = home.appendingPathComponent("Library/Preferences/\(bid).plist")
            let container = home.appendingPathComponent("Library/Containers/\(bid)/Data/Library/Preferences/\(bid).plist")
            return ScannableApp(bundleID: bid, name: name, plistURLs: [prefs], containerPlistURLs: [container])
        }
    }
}
