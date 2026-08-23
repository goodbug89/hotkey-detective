import SwiftUI
import ServiceManagement

@main
struct HotkeyDetectiveApp: App {
    @StateObject private var session = ProbeSession()

    var body: some Scene {
        MenuBarExtra("HotkeyDetective", systemImage: "keyboard.badge.ellipsis") {
            RootView().environmentObject(session).frame(width: 360)
        }
        .menuBarExtraStyle(.window)
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
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        HStack {
            Toggle("로그인 시 실행", isOn: $launchAtLogin)
                .toggleStyle(.checkbox).font(.caption)
                .onChange(of: launchAtLogin) { _, on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                }
            Spacer()
            Button("종료") { NSApplication.shared.terminate(nil) }.buttonStyle(.link).font(.caption)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }
}
