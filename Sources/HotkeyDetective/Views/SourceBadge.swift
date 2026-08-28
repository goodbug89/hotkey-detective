import SwiftUI

/// 증거 소스명 → 뱃지. 시스템/파서는 accent, 스캔·탐침은 중립.
struct SourceBadge: View {
    let source: String   // "시스템 단축키", "Rectangle 설정", "설정 스캔", "반응 감지", "핫키 등록 시도" 등

    /// 뱃지 글자 수가 달라도(시스템 3자 / 반응 2자) 뒤따르는 설명이 같은 x에서 시작하도록
    /// 칸 너비를 고정하고 왼쪽 정렬한다. 여러 근거 줄이 세 열로 맞아 읽기 쉬워진다.
    static let columnWidth: CGFloat = 46

    var body: some View {
        let (label, tint) = style
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
            .frame(width: Self.columnWidth, alignment: .leading)
    }
    private var style: (String, Color) {
        if source.contains("스캔") { return ("스캔", .secondary) }
        // 탐침 계열(ReactionResolver / CarbonOccupancyResolver)은 설정 파서가 아니다.
        if source.contains("반응") { return ("반응", .secondary) }
        if source.contains("등록 시도") { return ("탐침", .secondary) }
        if source.contains("시스템") { return ("시스템", .accentColor) }
        return ("파서", .accentColor)
    }
}
