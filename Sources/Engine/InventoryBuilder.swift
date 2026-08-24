import Foundation

public struct InventoryEntry: Hashable {
    public let combo: KeyCombo
    public let owners: [Owner]
    public let evidence: [Evidence]
    public var isConflict: Bool { Set(owners.map(\.identity)).count > 1 }
    public init(combo: KeyCombo, owners: [Owner], evidence: [Evidence]) {
        self.combo = combo; self.owners = owners; self.evidence = evidence
    }
}

public enum InventoryBuilder {
    public static func build(_ pairs: [(KeyCombo, Evidence)]) -> [InventoryEntry] {
        // 조합별 그룹핑 (KeyCombo는 Hashable)
        var byCombo: [KeyCombo: [Evidence]] = [:]
        var order: [KeyCombo] = []
        for (combo, e) in pairs {
            if byCombo[combo] == nil { order.append(combo) }
            byCombo[combo, default: []].append(e)
        }
        let entries = order.map { combo -> InventoryEntry in
            let evs = byCombo[combo]!
            return InventoryEntry(combo: combo, owners: mergeOwners(evs), evidence: evs)
        }
        // 충돌 먼저, 그다음 수정자 rawValue → keyCode 안정 정렬
        return entries.sorted { l, r in
            if l.isConflict != r.isConflict { return l.isConflict }
            if l.combo.modifiers.rawValue != r.combo.modifiers.rawValue {
                return l.combo.modifiers.rawValue < r.combo.modifiers.rawValue
            }
            return l.combo.keyCode < r.combo.keyCode
        }
    }

    /// v1 Owner.identity 병합 규칙과 동일: 앱은 bundleID, 시스템은 기능명. 액션 있는 쪽 유지.
    private static func mergeOwners(_ evidence: [Evidence]) -> [Owner] {
        var index: [String: Int] = [:], out: [Owner] = []
        for e in evidence {
            guard let o = e.owner else { continue }
            if let i = index[o.identity] {
                if case .app(_, _, nil) = out[i], case .app(_, _, .some) = o { out[i] = o }
            } else {
                index[o.identity] = out.count
                out.append(o)
            }
        }
        return out
    }
}
