import Foundation

/// symbolichotkeys ID → (기능명, 기본 조합, 기본 활성 여부).
/// `combo`가 있어도 macOS가 기본으로 끄고 출고하는 항목이 있으므로(접근성 확대/축소·색상 반전,
/// ⌃1–⌃4 데스크탑 전환 등) 활성 여부는 `defaultEnabled`로 따로 표현한다. 조합은 표시용으로 유지한다.
/// 출처: macOS 시스템 설정 > 키보드 > 키보드 단축키 화면 기본값. ID는 Apple 비공개 상수로 안정적.
public enum SymbolicHotKeyDefaults {
    static func c(_ k: UInt16, _ m: Modifiers) -> KeyCombo { KeyCombo(keyCode: k, modifiers: m) }

    public static let entries: [Int: (feature: String, combo: KeyCombo?, defaultEnabled: Bool)] = [
        // 접근성 줌/반전/대비: 조합은 예약돼 있으나 기본은 비활성
        15: ("화면 확대/축소 전환", c(28, [.command, .option]), false),
        17: ("확대", c(24, [.command, .option]), false),
        19: ("축소", c(27, [.command, .option]), false),
        21: ("색상 반전", c(28, [.command, .option, .control]), false),   // ⌃⌥⌘8 (Task 3 실사 교정: 원안 keyCode 8('C')는 오류)
        25: ("대비 높이기", c(47, [.command, .option, .control]), false),
        26: ("대비 낮추기", c(43, [.command, .option, .control]), false),

        27: ("다음 윈도우로 이동", c(50, [.command]), true),
        28: ("전체 화면 스크린샷 저장", c(20, [.command, .shift]), true),      // ⌘⇧3
        29: ("전체 화면 스크린샷 클립보드", c(20, [.command, .shift, .control]), true),
        30: ("영역 스크린샷", c(21, [.command, .shift]), true),                 // ⌘⇧4
        31: ("영역 스크린샷 클립보드", c(21, [.command, .shift, .control]), true),
        32: ("Mission Control", c(126, [.control]), true),
        33: ("응용 프로그램 윈도우", c(125, [.control]), true),
        34: ("Mission Control (마우스)", nil, false),
        36: ("데스크탑 보기", c(103, []), true),                                   // F11
        52: ("Dock 자동 숨기기 전환", c(2, [.command, .option]), true),         // ⌥⌘D
        57: ("키보드 초점 이동 전환", c(98, [.control]), false),                // ^F7, 기본 비활성
        59: ("메뉴 막대 이동", c(120, [.control]), true),                         // ^F2
        60: ("이전 입력 소스 선택", c(49, [.control]), true),                     // ^Space
        61: ("입력 메뉴의 다음 소스 선택", c(49, [.control, .option]), true),
        64: ("Spotlight 검색", c(49, [.command]), true),                          // ⌘Space
        65: ("Finder 검색 윈도우", c(49, [.command, .option]), true),
        79: ("왼쪽 Space로 이동", c(123, [.control]), true),
        81: ("오른쪽 Space로 이동", c(124, [.control]), true),

        // ⌃1–⌃4 데스크탑 직접 전환: 조합은 예약돼 있으나 기본은 비활성
        118: ("데스크탑 1로 전환", c(18, [.control]), false),
        119: ("데스크탑 2로 전환", c(19, [.control]), false),
        120: ("데스크탑 3로 전환", c(20, [.control]), false),
        121: ("데스크탑 4로 전환", c(21, [.control]), false),

        160: ("Launchpad 보기", nil, false),
        163: ("알림 센터 보기", nil, false),
        164: ("방해금지 모드 전환", nil, false),
        175: ("손쉬운 사용 단축키", c(96, [.command, .option]), true),           // ⌥⌘F5
        184: ("스크린샷 및 화면 기록 옵션", c(23, [.command, .shift]), true),   // ⌘⇧5
    ]

    public static func feature(for id: Int) -> String {
        entries[id]?.feature ?? "시스템 기능 #\(id)"
    }
}
