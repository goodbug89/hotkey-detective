import SwiftUI
import Engine
import Probe

@MainActor
final class InventoryModel: ObservableObject {
    @Published var entries: [InventoryEntry] = []
    @Published var query: String = ""
    @Published var conflictsOnly: Bool = false
    /// 샌드박스 앱의 설정까지 읽는다. macOS가 앱마다 권한을 물으므로 기본은 꺼짐.
    @Published var deepScan = false
    @Published var isLoading = false

    /// 스캔은 수십 개 plist를 읽는 디스크 작업이라 메인 액터를 막지 않게 detached로 돌린다.
    /// 실행 중 앱 목록만 메인에서 뽑고, resolver 조립·파싱은 전부 백그라운드에서 한다.
    func reload() {
        guard !isLoading else { return }
        isLoading = true
        let apps = RunningAppsProvider.scannableApps()
        let deep = deepScan
        Task {
            let built = await Task.detached {
                let enumerables: [Enumerable] = [SystemHotkeyResolver(),
                    HeuristicScanResolver(apps: apps,
                                          excludedBundleIDs: KnownApps.parserBundleIDs,
                                          includeContainers: deep)]
                    + KnownApps.all(running: WorkspaceRunningApps()).compactMap { $0 as? Enumerable }
                return InventoryBuilder.build(enumerables.flatMap { $0.allPairs() })
            }.value
            self.entries = built
            self.isLoading = false
        }
    }

    var filtered: [InventoryEntry] {
        entries.filter { e in
            (!conflictsOnly || e.isConflict) &&
            (query.isEmpty
             || e.combo.display.localizedCaseInsensitiveContains(query)
             || e.owners.contains { $0.displayName.localizedCaseInsensitiveContains(query) })
        }
    }

    var conflictCount: Int { entries.filter(\.isConflict).count }
}
