import Foundation

public enum Confidence: Int, Comparable, Codable {
    case low, medium, high, certain
    public static func < (a: Confidence, b: Confidence) -> Bool { a.rawValue < b.rawValue }
}

public enum Owner: Hashable, Codable {
    case system(feature: String)
    case app(bundleID: String, name: String, action: String?)

    /// 소유자 동일성 키: 앱은 bundleID, 시스템은 기능명. 액션은 무시한다.
    public var identity: String {
        switch self {
        case .system(let f): return "system:\(f)"
        case .app(let bid, _, _): return "app:\(bid)"
        }
    }

    public var displayName: String {
        switch self {
        case .system(let f): return "\(f) (시스템)"
        case .app(_, let name, let action):
            if let a = action { return "\(name) · \(a)" }
            return name
        }
    }
}

/// 증거가 무엇을 말하는지 구분한다.
///
/// `claim`은 "이 조합을 등록해뒀다"는 주장(시스템 plist, 앱 설정 파서, 설정 스캔)이고,
/// `observation`은 "이런 일이 일어났다"는 관찰(반응 감지, Carbon 점유 시도)이다.
///
/// 충돌 판정에서 둘은 대칭이 아니다. 반응은 키를 **가져간** 쪽에서 나오므로 승자를
/// 뒷받침할 뿐, 경쟁 등록의 근거가 될 수 없다 — 경쟁자는 오히려 반응하지 못한 쪽이다.
/// 이 구분이 없으면 ⌘Space처럼 시스템이 소유하고 시스템 UI가 반응하는 조합이
/// "시스템과 앱이 모두 등록함"으로 잘못 표시된다.
public enum EvidenceKind: Hashable, Codable {
    case claim
    case observation
}

public struct Evidence: Hashable, Codable {
    public let source: String
    public let owner: Owner?
    public let confidence: Confidence
    public let rationale: String
    public let kind: EvidenceKind

    public init(source: String, owner: Owner?, confidence: Confidence, rationale: String,
                kind: EvidenceKind = .claim) {
        self.source = source; self.owner = owner; self.confidence = confidence
        self.rationale = rationale; self.kind = kind
    }
}

public enum Verdict {
    case confirmed(Owner, [Evidence])
    case likely(Owner, [Evidence])
    case contested([Owner], [Evidence])
    case occupiedUnknown([Evidence])
    case free([Evidence])

    public var evidence: [Evidence] {
        switch self {
        case .confirmed(_, let e), .likely(_, let e), .contested(_, let e), .occupiedUnknown(let e), .free(let e): return e
        }
    }
}
