import AppKit
import SwiftUI
import Engine

/// 증거 소스 뱃지. 라벨과 색은 `EvidenceSource` 케이스로 고른다 —
/// v2까지는 소스 이름 문자열을 `contains("스캔")` 식으로 검사해서 언어가 바뀌면 깨질 구조였다.
struct SourceBadge: View {
    let source: EvidenceSource

    /// 뱃지 글자 수가 언어마다 달라도 뒤따르는 설명이 같은 x에서 시작하도록 칸 너비를 고정한다.
    ///
    /// 64pt로 못박아 뒀더니 러시아어 "Настройки", 이탈리아어 "Scansione", 아랍어 "الإعدادات"가
    /// "Настро…"로 잘렸다. 언어별로 숫자를 손보는 대신 그 언어의 가장 긴 뱃지를 실제로 재서
    /// 칸을 잡는다 — 정렬(같은 x에서 설명 시작)은 그대로 지키면서 어떤 언어에서도 안 잘린다.
    static let columnWidth: CGFloat = {
        let labels = [EvidenceSource.systemHotkeys, .knownAppParser(appName: ""),
                      .heuristicScan, .reaction, .carbonProbe].map(\.badgeLabel)
        let font = NSFont.preferredFont(forTextStyle: .caption2)
        let widest = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 52
        // 캡슐 좌우 여백(6+6)과 글꼴 렌더링 오차를 더한다.
        return max(64, ceil(widest) + 16)
    }()

    var body: some View {
        Text(source.badgeLabel)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(source.badgeTint.opacity(0.15), in: Capsule())
            .foregroundStyle(source.badgeTint)
            .frame(width: Self.columnWidth, alignment: .leading)
    }

    /// 뱃지 라벨이 서로 다른 소스만 첫 등장 순서대로 골라준다.
    /// 충돌 행에서 "시스템 + 설정"처럼 관련된 소스를 모두 보여줄 때 쓴다.
    static func distinctSources(of sources: [EvidenceSource]) -> [EvidenceSource] {
        var seen = Set<String>(), out: [EvidenceSource] = []
        for s in sources where seen.insert(s.badgeLabel).inserted { out.append(s) }
        return out
    }
}
