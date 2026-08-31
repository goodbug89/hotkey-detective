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
            // 두 버튼 문구는 어떤 언어에서도 360pt 한 줄에 들어가지 않는다 — 영어조차
            // "Open Accessibility sett..."로 잘렸다. 권한 화면은 새 사용자가 처음 보는
            // 화면이라 잘린 버튼이 곧 첫인상이 된다. 들어갈 때만 한 줄로 둔다.
            ViewThatFits(in: .horizontal) {
                HStack { accessibilityButton; inputMonitoringButton }
                VStack(alignment: .leading, spacing: 8) { accessibilityButton; inputMonitoringButton }
            }
            Button(L.t("permission.limitedMode")) { session.useLimitedMode() }
                .buttonStyle(.link).font(.caption)
        }
        .padding()
    }

    private var accessibilityButton: some View {
        Button(L.t("permission.openAccessibility")) { session.requestPermission() }
            .buttonStyle(.borderedProminent)
    }

    private var inputMonitoringButton: some View {
        Button(L.t("permission.openInputMonitoring")) { session.openInputMonitoringSettings() }
            .buttonStyle(.bordered)
    }
}
