import SwiftUI
import Engine

struct ProbeView: View {
    @EnvironmentObject var session: ProbeSession
    @State private var showManual = false
    var body: some View {
        VStack(spacing: 12) {
            if session.limitedMode {
                Text(L.t("probe.limitedMode")).font(.caption).foregroundStyle(.orange)
            } else {
                Button(L.t("probe.start")) { session.startListening() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            Button(showManual ? L.t("probe.manual.close") : L.t("probe.manual.toggle")) { showManual.toggle() }
                .buttonStyle(.link).font(.caption)
            if showManual || session.limitedMode {
                ManualComboView { session.probe(manual: $0) }
            }
        }
        .padding()
    }
}

struct ListeningView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        VStack(spacing: 12) {
            RadarView()
            Text(L.t("probe.listening.title")).font(.headline)
            Text("Esc로 취소 · 15초 후 자동 종료").font(.caption).foregroundStyle(.secondary)
            Button(L.t("probe.cancel")) { session.cancelListening() }.buttonStyle(.link)
        }
        .padding()
    }
}
