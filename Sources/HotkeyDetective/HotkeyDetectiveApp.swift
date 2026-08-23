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
        Text("상태: \(String(describing: session.state))").padding()
    }
}
