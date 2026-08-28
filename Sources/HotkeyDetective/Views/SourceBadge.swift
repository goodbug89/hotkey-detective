import SwiftUI

/// 증거 소스명 → 뱃지. 시스템/파서는 accent, 스캔·탐침은 중립.
struct SourceBadge: View {
    let source: String   // "시스템 단축키", "Rectangle 설정", "설정 스캔", "반응 감지", "핫키 등록 시도" 등

    /// 뱃지 글자 수가 달라도(시스템 3자 / 반응 2자) 뒤따르는 설명이 같은 x에서 시작하도록
    /// 칸 너비를 고정하고 왼쪽 정렬한다. 여러 근거 줄이 세 열로 맞아 읽기 쉬워진다.
    static let columnWidth: CGFloat = 46

    var body: some View {
        let (label, tint) = Self.style(for: source)
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
            .frame(width: Self.columnWidth, alignment: .leading)
    }

    /// 소스 문자열 → (뱃지 라벨, 색). 여러 소스를 라벨 기준으로 중복 제거할 때도 쓴다
    /// ("Maccy 설정"과 "Rectangle 설정"은 둘 다 "파서"라 한 번만 보여주면 된다).
    static func style(for source: String) -> (String, Color) {
        if source.contains("스캔") { return ("스캔", .secondary) }
        // 탐침 계열(ReactionResolver / CarbonOccupancyResolver)은 설정 파서가 아니다.
        if source.contains("반응") { return ("반응", .secondary) }
        if source.contains("등록 시도") { return ("탐침", .secondary) }
        if source.contains("시스템") { return ("시스템", .accentColor) }
        return ("파서", .accentColor)
    }

    /// 뱃지 라벨이 서로 다른 소스만 첫 등장 순서대로 골라준다.
    /// 충돌 행에서 "시스템 + 파서"처럼 관련된 소스를 모두 보여줄 때 쓴다.
    static func distinctSources(of sources: [String]) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for s in sources where seen.insert(style(for: s).0).inserted { out.append(s) }
        return out
    }
}
