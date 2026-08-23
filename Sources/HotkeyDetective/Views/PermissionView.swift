import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("손쉬운 사용 · 입력 모니터링 권한이 필요합니다", systemImage: "hand.raised")
                .font(.headline)
            Text("어떤 앱이 단축키에 반응하는지 보려면 키 입력을 관찰해야 합니다. macOS는 이를 위해 **손쉬운 사용**과 **입력 모니터링** 권한을 모두 요구합니다. 두 목록 모두에서 HotkeyDetective를 켜주세요. 입력은 가로채거나 저장하지 않습니다.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("손쉬운 사용 설정 열기") { session.requestPermission() }
                    .buttonStyle(.borderedProminent)
                Button("입력 모니터링 설정 열기") { session.openInputMonitoringSettings() }
                    .buttonStyle(.bordered)
            }
            Button("권한 없이 제한 모드 사용") { session.useLimitedMode() }
                .buttonStyle(.link).font(.caption)
        }
        .padding()
    }
}
