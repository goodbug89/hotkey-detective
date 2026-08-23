import SwiftUI

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
        Group {
            switch session.state {
            case .needsPermission: PermissionView()
            case .idle: ProbeView()
            case .listening: ListeningView()
            case .resolving(let c): VStack { Text(c.display).font(.largeTitle); ProgressView() }.padding()
            case .result(let c, let v): VerdictView(combo: c, verdict: v)
            }
        }
        .frame(width: 360)
    }
}
