import AppKit
import ApplicationServices
import IOKit.hid

public enum AccessibilityGate {
    /// 이벤트 탭을 실제로 만들려면 손쉬운 사용과 입력 모니터링 권한이 **둘 다** 필요하다.
    public static func isTrusted(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let ax = AXIsProcessTrustedWithOptions(opts)
        if prompt { _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }
        return ax && IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    public static func openSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public static func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private static func open(_ string: String) {
        NSWorkspace.shared.open(URL(string: string)!)
    }
}
