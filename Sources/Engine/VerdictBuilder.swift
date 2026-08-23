import Foundation

public enum VerdictBuilder {
    public static func build(_ evidence: [Evidence]) -> Verdict {
        if evidence.isEmpty { return .free([]) }

        let sorted = evidence.sorted { $0.confidence > $1.confidence }

        // 규칙 1: certain
        let certainOwners = uniqueOwners(sorted.filter { $0.confidence == .certain })
        if certainOwners.count == 1 { return .confirmed(certainOwners[0], sorted) }
        if certainOwners.count > 1 { return .contested(certainOwners, sorted) }

        // 규칙 2~3: medium 이상 non-nil owner
        let candidates = uniqueOwners(sorted.filter { $0.confidence >= .medium })
        if candidates.count == 1 { return .likely(candidates[0], sorted) }
        if candidates.count > 1 { return .contested(candidates, sorted) }

        // 규칙 4: owner는 없지만 medium 이상 증거(Carbon 점유 등)
        if sorted.contains(where: { $0.confidence >= .medium }) { return .occupiedUnknown(sorted) }

        // 규칙 5: low만 남음
        return .free(sorted)
    }

    /// 신뢰도 내림차순을 유지하며 owner 중복 제거 (nil 제외)
    private static func uniqueOwners(_ evidence: [Evidence]) -> [Owner] {
        var seen = Set<Owner>(), out: [Owner] = []
        for e in evidence {
            guard let o = e.owner, !seen.contains(o) else { continue }
            seen.insert(o); out.append(o)
        }
        return out
    }
}
