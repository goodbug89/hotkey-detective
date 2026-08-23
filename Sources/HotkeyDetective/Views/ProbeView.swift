import SwiftUI
import Engine

struct ProbeView: View {
    @EnvironmentObject var session: ProbeSession
    @State private var showManual = false
    var body: some View {
        VStack(spacing: 12) {
            if session.limitedMode {
                Text("제한 모드 — 설정 파일 기반으로만 판정합니다").font(.caption).foregroundStyle(.orange)
            } else {
                Button("탐침 시작") { session.startListening() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            Button(showManual ? "조합 직접 지정 닫기" : "조합을 직접 지정") { showManual.toggle() }
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
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 12) {
            Circle().fill(.blue).frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
                .onAppear { pulse = true }
            Text("지금 조합을 눌러보세요").font(.headline)
            Text("Esc로 취소 · 15초 후 자동 종료").font(.caption).foregroundStyle(.secondary)
            Button("취소") { session.cancelListening() }.buttonStyle(.link)
        }
        .padding()
    }
}
