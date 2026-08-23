import AppKit
import SwiftUI
import Engine

struct VerdictView: View {
    @EnvironmentObject var session: ProbeSession
    let combo: KeyCombo
    let verdict: Verdict

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(combo.display).font(.system(size: 34, weight: .semibold, design: .rounded))
            headline
            DisclosureGroup("근거 \(verdict.evidence.count)건", isExpanded: .constant(true)) {
                ForEach(Array(verdict.evidence.enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .top, spacing: 8) {
                        dots(e.confidence)
                        VStack(alignment: .leading) {
                            Text(e.source).font(.caption.bold())
                            Text(e.rationale).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if case .occupiedUnknown(_) = verdict {
                Text("아직 모르는 앱일 수 있어요. 짐작 가는 앱을 종료하고 다시 시도해보세요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                ownerAction
                Spacer()
                Button("결과 복사") { copy() }
                Button("다시 탐침") { session.reset() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    @ViewBuilder private var headline: some View {
        switch verdict {
        case .confirmed(let o, _): styled("\(o.displayName)이(가) 사용 중", .blue)
        case .likely(let o, _): styled("\(o.displayName)이(가) 사용 중인 것으로 보임", .blue)
        case .contested(let os, _): styled(os.map(\.displayName).joined(separator: "와 ") + "이(가) 모두 등록함", .orange)
        case .occupiedUnknown(_): styled("어떤 앱이 점유 중이지만 누구인지 찾지 못함", .gray)
        case .free(_): styled("아무도 사용하지 않음", .green)
        }
    }

    private func styled(_ s: String, _ c: Color) -> some View {
        Text(s).font(.headline).foregroundStyle(c)
    }

    private func dots(_ c: Confidence) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(i <= c.rawValue ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 5, height: 5)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var ownerAction: some View {
        switch primaryOwner {
        case .system(_)?:
            Button("키보드 단축키 설정 열기") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
            }
        case .app(let bid, let name, _)?:
            Button("\(name) 열기") {
                NSRunningApplication.runningApplications(withBundleIdentifier: bid).first?.activate()
            }
        case nil: EmptyView()
        }
    }

    private var primaryOwner: Owner? {
        switch verdict {
        case .confirmed(let o, _), .likely(let o, _): return o
        case .contested(let os, _): return os.first
        default: return nil
        }
    }

    private func copy() {
        var s = "\(combo.display)\n"
        switch verdict {
        case .confirmed(let o, _): s += "사용 중: \(o.displayName)\n"
        case .likely(let o, _): s += "사용 중(추정): \(o.displayName)\n"
        case .contested(let os, _): s += "충돌: \(os.map(\.displayName).joined(separator: ", "))\n"
        case .occupiedUnknown(_): s += "점유됨(소유자 미상)\n"
        case .free(_): s += "비어 있음\n"
        }
        for e in verdict.evidence { s += "- [\(e.source)] \(e.rationale)\n" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
