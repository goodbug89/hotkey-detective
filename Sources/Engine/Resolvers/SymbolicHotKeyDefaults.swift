import Foundation

/// symbolichotkeys ID → (기능명, 기본 조합). 기본 조합이 nil이면 기본적으로 비활성.
/// 출처: macOS 시스템 설정 > 키보드 > 키보드 단축키 화면 기본값. ID는 Apple 비공개 상수로 안정적.
public enum SymbolicHotKeyDefaults {
    static func c(_ k: UInt16, _ m: Modifiers) -> KeyCombo { KeyCombo(keyCode: k, modifiers: m) }

    public static let entries: [Int: (feature: String, combo: KeyCombo?)] = [
        7: ("Dock 가리기/보기", c(2, [.command, .option])),
        15: ("화면 확대/축소 전환", c(28, [.command, .option])),
        17: ("확대", c(24, [.command, .option])),
        19: ("축소", c(27, [.command, .option])),
        21: ("색상 반전", c(28, [.command, .option, .control])),          // ⌃⌥⌘8 (Task 3 실사 교정: 원안 keyCode 8('C')는 오류)
        25: ("대비 높이기", c(47, [.command, .option, .control])),
        26: ("대비 낮추기", c(43, [.command, .option, .control])),
        27: ("다음 윈도우로 이동", c(50, [.command])),
        28: ("전체 화면 스크린샷 저장", c(20, [.command, .shift])),      // ⌘⇧3
        29: ("전체 화면 스크린샷 클립보드", c(20, [.command, .shift, .control])),
        30: ("영역 스크린샷", c(21, [.command, .shift])),                 // ⌘⇧4
        31: ("영역 스크린샷 클립보드", c(21, [.command, .shift, .control])),
        32: ("Mission Control", c(126, [.control])),
        33: ("응용 프로그램 윈도우", c(125, [.control])),
        34: ("Mission Control (마우스)", nil),
        36: ("데스크탑 보기", c(103, [])),                                   // F11
        52: ("Dock 포커스", c(99, [.control])),                             // ⌃F3 (Task 3 실사 교정: 원안 keyCode 3('F')는 오류)
        57: ("키보드 초점 이동 전환", c(98, [.control])),                  // ^F7 (Task 3 실사 교정: 원안 keyCode 111(F12)는 주석과 불일치)
        59: ("메뉴 막대 이동", c(120, [.control])),                         // ^F2
        60: ("이전 입력 소스 선택", c(49, [.control])),                     // ^Space
        61: ("입력 메뉴의 다음 소스 선택", c(49, [.control, .option])),
        64: ("Spotlight 검색", c(49, [.command])),                          // ⌘Space
        65: ("Finder 검색 윈도우", c(49, [.command, .option])),
        79: ("왼쪽 Space로 이동", c(123, [.control])),
        81: ("오른쪽 Space로 이동", c(124, [.control])),
        118: ("데스크탑 1로 전환", c(18, [.control])),
        119: ("데스크탑 2로 전환", c(19, [.control])),
        120: ("데스크탑 3로 전환", c(20, [.control])),
        121: ("데스크탑 4로 전환", c(21, [.control])),
        160: ("Launchpad 보기", nil),
        163: ("알림 센터 보기", nil),
        164: ("방해금지 모드 전환", nil),
        175: ("손쉬운 사용 단축키", c(96, [.command, .option])),           // ⌥⌘F5
        184: ("스크린샷 및 화면 기록 옵션", c(23, [.command, .shift])),   // ⌘⇧5
    ]

    public static func feature(for id: Int) -> String {
        entries[id]?.feature ?? "시스템 기능 #\(id)"
    }
}
