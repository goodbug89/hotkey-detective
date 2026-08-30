import SwiftUI
import Engine

struct InventoryWindow: View {
    @StateObject private var model = InventoryModel()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                Text(L.t("inventory.title")).font(.headline)
                Text(L.count("inventory.summary", model.entries.count, model.conflictCount))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                TextField(L.t("inventory.search"), text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    // 160pt 고정이면 독일어 자리표시자가 "…App suc"로 잘린다.
                    // 언어마다 길이가 다르므로 창 너비에 맞춰 늘어나게 둔다.
                    .frame(minWidth: 160, idealWidth: 240, maxWidth: 320)
                Toggle(L.t("inventory.conflictsOnly"), isOn: $model.conflictsOnly).toggleStyle(.button)
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .padding(.horizontal, 12).padding(.top, 12)
            HStack(spacing: 8) {
                Toggle(L.t("inventory.deepScan"), isOn: $model.deepScan)
                    .toggleStyle(.checkbox).font(.caption)
                    .onChange(of: model.deepScan) { _, _ in model.reload() }
                Text(L.t("inventory.deepScan.hint"))
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
                        // 근거가 전부 low면 "등록돼 있으나 지금 실행 중이 아님" — 실행 중인
                        // 항목과 구분되지 않으면 지금 충돌하는 것으로 오해된다.
                        if e.isDormant {
                            Text(L.t("inventory.dormant"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    // 충돌 행은 관련된 소스를 모두 보여준다. 하나만 보이면 상대가 확실한
                    // 파서인지 약한 스캔 추정인지 알 수 없다.
                    ForEach(SourceBadge.distinctSources(of: e.evidence.map(\.source)), id: \.self) { src in
                        SourceBadge(source: src)
                    }
                }
                .padding(.vertical, 3)
                .opacity(e.isDormant ? 0.55 : 1)
                .listRowBackground(e.isConflict ? Color.orange.opacity(0.08) : Color.clear)
            }
            // 탐침 팝오버(자주 쓰는 경로)에는 넣지 않는다 — 사용자가 일부러 연 창에서만,
            // 한 줄로.
            //
            // safeAreaInset으로 얹었더니 마지막 행 위에 겹쳐 그려졌다. 바깥 VStack에
            // 붙여도, List에 직접 붙여도 마찬가지였다(둘 다 실기 확인). 스크롤 내용까지
            // 안전 영역이 전해지지 않는다. 스택의 형제로 두면 자리를 실제로 차지하므로
            // 겹칠 수가 없다 — 내용 아래로 스크롤이 지나가는 효과는 포기한다.
            Divider()
            HStack {
                Spacer()
                Link(L.t("footer.madeBy"), destination: URL(string: "https://unifyl.app")!)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear { model.reload() }
    }
}
