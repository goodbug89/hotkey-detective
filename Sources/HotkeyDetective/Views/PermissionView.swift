import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L.t("permission.title"), systemImage: "hand.raised")
                .font(.headline)
            Text(LocalizedStringKey(L.t("permission.body")))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L.t("permission.openAccessibility")) { session.requestPermission() }
                    .buttonStyle(.borderedProminent)
                Button(L.t("permission.openInputMonitoring")) { session.openInputMonitoringSettings() }
                    .buttonStyle(.bordered)
            }
            Button(L.t("permission.limitedMode")) { session.useLimitedMode() }
                .buttonStyle(.link).font(.caption)
        }
        .padding()
    }
}
