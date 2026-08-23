import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var session: ProbeSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("손쉬운 사용 권한이 필요합니다", systemImage: "hand.raised")
                .font(.headline)
            Text("어떤 앱이 단축키에 반응하는지 보려면 키 입력을 관찰해야 합니다. 입력은 가로채거나 저장하지 않습니다.")
                .font(.callout).foregroundStyle(.secondary)
            Button("시스템 설정 열기") { session.requestPermission() }
                .buttonStyle(.borderedProminent)
            Button("권한 없이 제한 모드 사용") { session.useLimitedMode() }
                .buttonStyle(.link).font(.caption)
        }
        .padding()
    }
}
