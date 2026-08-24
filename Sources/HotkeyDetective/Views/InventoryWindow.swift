import SwiftUI
import Engine

struct InventoryWindow: View {
    @StateObject private var model = InventoryModel()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                Text("전체 단축키").font(.headline)
                Text("등록 \(model.entries.count) · 충돌 \(model.conflictCount)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                TextField("조합·앱 검색", text: $model.query).textFieldStyle(.roundedBorder).frame(width: 160)
                Toggle("충돌만", isOn: $model.conflictsOnly).toggleStyle(.button)
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .padding(.horizontal, 12).padding(.top, 12)
            HStack(spacing: 8) {
                Toggle("심층 스캔", isOn: $model.deepScan)
                    .toggleStyle(.checkbox).font(.caption)
                    .onChange(of: model.deepScan) { _, _ in model.reload() }
                Text("샌드박스 앱의 설정까지 읽습니다 — macOS가 앱마다 접근 권한을 물어봅니다.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 10)
            Divider()
            List(model.filtered, id: \.combo) { e in
                HStack(alignment: .top, spacing: 12) {
                    Text(e.combo.display)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(e.isConflict ? Color.orange : .primary)
                        .frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        if e.isConflict {
                            Label(e.owners.map(\.displayName).joined(separator: " · "), systemImage: "exclamationmark.triangle")
                                .font(.callout).foregroundStyle(.orange)
                        } else {
                            Text(e.owners.first?.displayName ?? "—").font(.callout)
                        }
                    }
                    Spacer()
                    if let src = e.evidence.first?.source { SourceBadge(source: src) }
                }
                .padding(.vertical, 3)
                .listRowBackground(e.isConflict ? Color.orange.opacity(0.08) : Color.clear)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear { model.reload() }
    }
}
