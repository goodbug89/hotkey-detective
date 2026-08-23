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

public struct Evidence: Hashable, Codable {
    public let source: String
    public let owner: Owner?
    public let confidence: Confidence
    public let rationale: String

    public init(source: String, owner: Owner?, confidence: Confidence, rationale: String) {
        self.source = source; self.owner = owner; self.confidence = confidence; self.rationale = rationale
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
