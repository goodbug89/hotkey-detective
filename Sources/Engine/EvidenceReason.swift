import Foundation

/// 증거가 왜 나왔는지를 **구조화해서** 담는다.
///
/// v2까지 `Evidence.rationale`은 완성된 한국어 문장이었다. 순수 로직 계층이 표시 문구를
/// 만들면 다국어를 지원할 수 없고(조사 처리까지 얽힌다), Engine이 UI 정책을 떠안게 된다.
/// 이제 Engine은 사실만 담고, 문장 조립은 표시 계층이 각 언어로 한다.
public enum EvidenceReason: Hashable, Codable {
    /// 시스템 심볼릭 핫키 항목이 이 조합으로 활성화돼 있다.
    case systemHotkey(id: Int, combo: String)
    /// 알려진 앱의 설정에서 단축키를 찾았다. `isRunning == false`면 지금은 충돌하지 않는다.
    case knownApp(app: String, action: String, combo: String, isRunning: Bool)
    /// 범용 스캔이 알려진 직렬화 패턴을 찾았다.
    case scanPattern(app: String, action: String?, combo: String)
    /// 입력 직후 앱이 반응했다(창 표시/활성 전환).
    case reaction(app: String, milliseconds: Int, signals: [ReactionSignal])
    /// 다른 프로세스가 Carbon 핫키로 등록해 두었다(소유자는 알 수 없다).
    case carbonOccupied(combo: String)

    public enum ReactionSignal: Hashable, Codable {
        case newWindows(count: Int)
        case becameFrontmost
    }
}
