import SwiftUI
import ServiceManagement
import os

@main
struct HotkeyDetectiveApp: App {
    @StateObject private var session = ProbeSession()

    var body: some Scene {
        MenuBarExtra("HotkeyDetective", systemImage: "keyboard.badge.ellipsis") {
            RootView().environmentObject(session).frame(width: 360)
        }
        .menuBarExtraStyle(.window)
        Window("전체 단축키", id: "inventory") { InventoryWindow() }
    }
}

struct RootView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch session.state {
                case .needsPermission: PermissionView()
                case .idle: ProbeView()
                case .listening: ListeningView()
                case .resolving(let c): VStack { Text(c.display).font(.largeTitle); ProgressView() }.padding()
                case .result(let c, let v): VerdictView(combo: c, verdict: v)
                }
            }
            Divider()
            FooterMenu()
        }
        .frame(width: 360)
    }
}

struct FooterMenu: View {
    @Environment(\.openWindow) private var openWindow
    private static let log = Logger(subsystem: "HotkeyDetective", category: "launchAtLogin")
    /// `.requiresApproval`도 사용자 의도상 "켜짐"으로 본다 — 승인만 남은 상태다.
    private static var isOn: Bool {
        let s = SMAppService.mainApp.status
        return s == .enabled || s == .requiresApproval
    }

    @State private var launchAtLogin = FooterMenu.isOn
    /// 실패 후 값을 되돌릴 때 onChange가 다시 서비스를 호출하지 않도록 막는다.
    @State private var suppressChange = false

    var body: some View {
        HStack {
            Toggle("로그인 시 실행", isOn: $launchAtLogin)
                .toggleStyle(.checkbox).font(.caption)
                .onChange(of: launchAtLogin) { _, on in
                    if suppressChange { suppressChange = false; return }
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        Self.log.error("로그인 항목 \(on ? "등록" : "해제") 실패: \(error.localizedDescription, privacy: .public)")
                        let actual = Self.isOn
                        if actual != launchAtLogin { suppressChange = true; launchAtLogin = actual }
                    }
                }
            Spacer()
            Button("전체 단축키 보기") { openWindow(id: "inventory") }
                .buttonStyle(.link).font(.caption)
            Button("종료") { NSApplication.shared.terminate(nil) }.buttonStyle(.link).font(.caption)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }
}
