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

    /// 표시용 문구는 UI가 언어별로 만든다(App 계층 `Owner.displayName`).
    /// Engine은 구성 요소만 노출한다.
    public var parts: (feature: String?, appName: String?, action: String?) {
        switch self {
        case .system(let f): return (f, nil, nil)
        case .app(_, let name, let action): return (nil, name, action)
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
    /// 어떤 Resolver가 냈는지를 가리키는 안정적인 키. 표시 문구는 UI가 언어별로 고른다.
    public let source: EvidenceSource
    public let owner: Owner?
    public let confidence: Confidence
    /// 왜 이 증거가 나왔는지 — 구조화된 사실. 문장 조립은 표시 계층의 몫이다.
    public let reason: EvidenceReason
    public let kind: EvidenceKind

    public init(source: EvidenceSource, owner: Owner?, confidence: Confidence,
                reason: EvidenceReason, kind: EvidenceKind = .claim) {
        self.source = source; self.owner = owner; self.confidence = confidence
        self.reason = reason; self.kind = kind
    }
}

/// 증거의 출처. 뱃지 라벨과 색을 고르는 기준이며, 문자열 매칭 대신 이 값으로 판단한다.
/// (v2에서는 소스 이름 문자열을 `contains("스캔")` 식으로 검사해 다국어에서 깨질 구조였다.)
public enum EvidenceSource: Hashable, Codable {
    case systemHotkeys
    case knownAppParser(appName: String)
    case heuristicScan
    case reaction
    case carbonProbe

    /// 표시 순서를 결정적으로 만들기 위한 정렬 키. 신뢰도가 같을 때 강한 근거부터 보이게 한다.
    var sortKey: (Int, String) {
        switch self {
        case .systemHotkeys: return (0, "")
        case .knownAppParser(let app): return (1, app)
        case .heuristicScan: return (2, "")
        case .reaction: return (3, "")
        case .carbonProbe: return (4, "")
        }
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
