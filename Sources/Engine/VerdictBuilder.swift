import Foundation

public enum VerdictBuilder {
    public static func build(_ evidence: [Evidence]) -> Verdict {
        if evidence.isEmpty { return .free([]) }

        // 신뢰도 내림차순, 동률은 source → rationale 순으로 안정적인 표시 순서를 만든다.
        let sorted = evidence.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            if $0.source != $1.source { return $0.source < $1.source }
            return $0.rationale < $1.rationale
        }

        // 규칙 1: certain. 단, certain 소유자가 하나여도 다른 소유자가 high 이상 증거를
        // 가지면 contested — "시스템 단축키인데 앱도 등록한" 실제 충돌이 바로 이 모양이다.
        let certainOwners = uniqueOwners(sorted.filter { $0.confidence == .certain })
        if certainOwners.count > 1 { return .contested(certainOwners, sorted) }
        if let certain = certainOwners.first {
            let rivals = uniqueOwners(sorted.filter { $0.confidence >= .high })
                .filter { $0.identity != certain.identity }
            if rivals.isEmpty { return .confirmed(certain, sorted) }
            return .contested([certain] + rivals, sorted)
        }

        // 규칙 2~3: medium 이상 non-nil owner
        let candidates = uniqueOwners(sorted.filter { $0.confidence >= .medium })
        if candidates.count == 1 { return .likely(candidates[0], sorted) }
        if candidates.count > 1 { return .contested(candidates, sorted) }

        // 규칙 4: owner는 없지만 medium 이상 증거(Carbon 점유 등)
        if sorted.contains(where: { $0.confidence >= .medium }) { return .occupiedUnknown(sorted) }

        // 규칙 5: low만 남음
        return .free(sorted)
    }

    /// 신뢰도 내림차순을 유지하며 owner 중복 제거 (nil 제외).
    /// 앱은 bundleID, 시스템은 기능명으로 동일성을 판단한다 — 같은 앱을 가리키는 증거가
    /// 액션 유무만 달라도(설정 파서 vs 반응 감지) 한 소유자로 합치고, 액션이 있는 쪽을 남긴다.
    private static func uniqueOwners(_ evidence: [Evidence]) -> [Owner] {
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
