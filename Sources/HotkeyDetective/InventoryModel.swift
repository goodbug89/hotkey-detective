import SwiftUI
import Engine
import Probe

@MainActor
final class InventoryModel: ObservableObject {
    @Published var entries: [InventoryEntry] = []
    @Published var query: String = ""
    @Published var conflictsOnly: Bool = false

    func reload() {
        let enumerables: [Enumerable] = [SystemHotkeyResolver(),
            HeuristicScanResolver(apps: RunningAppsProvider.scannableApps(),
                                  excludedBundleIDs: KnownApps.parserBundleIDs)]
            + KnownApps.all(running: WorkspaceRunningApps()).compactMap { $0 as? Enumerable }
        let pairs = enumerables.flatMap { $0.allPairs() }
        entries = InventoryBuilder.build(pairs)
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
