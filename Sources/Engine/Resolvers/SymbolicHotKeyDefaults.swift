import Foundation
import os

/// symbolichotkeys ID → (표시명, 기본 조합, 기본 활성 여부).
///
/// 출처는 macOS가 제공하는 `DefaultShortcutsTable.xml`이다. 이 표를 손으로 유지하던
/// v1~v2에서는 잘못된 항목 4개(ID 7/57/59/175)와 누락 22개가 있었고 그대로 certain
/// 오판을 냈다. 이제 런타임에 시스템 표를 읽고, 없을 때만 생성된 폴백을 쓴다.
public enum SymbolicHotKeyDefaults {
    private static let log = Logger(subsystem: "HotkeyDetective", category: "defaults")

    /// macOS 키보드 설정 확장의 기본 단축키 표. 비공개 경로라 없을 수 있다.
    static let systemTableURL = URL(fileURLWithPath:
        "/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex"
        + "/Contents/Resources/en.lproj/DefaultShortcutsTable.xml")

    public struct Entry {
        public let id: Int
        public let feature: String
        public let combo: KeyCombo?
        public let defaultEnabled: Bool
    }

    /// 한 번만 계산한다. 시스템 표 → 실패 시 생성된 폴백.
    public static let all: [Entry] = load()

    public static let entries: [Int: (feature: String, combo: KeyCombo?, defaultEnabled: Bool)] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, ($0.feature, $0.combo, $0.defaultEnabled)) })

    /// 시스템 표에 없는 ID는 일반 이름으로 둔다.
    /// 사용자 plist에는 표에 없는 ID가 실제로 나타난다(이 머신 기준 10개: 16/18/20/22/24/34/80/82/164/176).
    /// 대부분 비활성이거나 키가 없어 증거를 만들지 않고, 남는 것도 이름만 일반화된다.
    /// 이름을 추측해 채우면 v1~v2에서 certain 오판을 냈던 실패로 되돌아가므로 하지 않는다.
    public static func feature(for id: Int) -> String {
        entries[id]?.feature ?? "시스템 기능 #\(id)"
    }

    // MARK: - 적재

    static func load() -> [Entry] {
        if let rows = parseSystemTable(at: systemTableURL), !rows.isEmpty {
            log.debug("시스템 단축키 표 사용: \(rows.count)개")
            return rows.map(entry(from:))
        }
        log.debug("시스템 표 없음 — 생성된 폴백 사용")
        return GeneratedShortcutTable.rows
            .map { Row(id: $0.id, name: $0.name, keyCode: $0.keyCode, modifier: $0.modifier, enabled: $0.enabled) }
            .map(entry(from:))
    }

    struct Row {
        let id: Int, name: String, keyCode: UInt16?, modifier: UInt64, enabled: Bool
    }

    /// 시스템 XML을 파싱한다. 구조가 바뀌면 nil을 돌려 폴백으로 넘어간다.
    static func parseSystemTable(at url: URL) -> [Row]? {
        guard let data = try? Data(contentsOf: url),
              let groups = (try? PropertyListSerialization.propertyList(from: data, format: nil))
                as? [[String: Any]] else { return nil }
        var rows: [Row] = []
        func walk(_ elements: [[String: Any]]) {
            for e in elements {
                if let id = e["sybmolichotkey"] as? Int {   // Apple의 오타를 그대로 따른다
                    let raw = (e["name"] as? String) ?? ""
                    let key = e["key"] as? Int
                    rows.append(Row(id: id,
                                    name: raw.replacingOccurrences(of: "DO_NOT_LOCALIZE: ", with: ""),
                                    keyCode: (key == 65535 || key == nil) ? nil : UInt16(key!),
                                    modifier: (e["modifier"] as? NSNumber)?.uint64Value ?? 0,
                                    enabled: (e["enabled"] as? Bool) ?? true))
                }
                if let nested = e["elements"] as? [[String: Any]] { walk(nested) }
            }
        }
        for g in groups { walk((g["elements"] as? [[String: Any]]) ?? []) }
        var seen = Set<Int>()
        return rows.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }

    static func entry(from r: Row) -> Entry {
        Entry(id: r.id,
              feature: displayNames[r.id] ?? r.name,
              combo: combo(keyCode: r.keyCode, modifier: r.modifier),
              defaultEnabled: r.enabled)
    }

    /// fn+화살표는 macOS가 키보드 단계에서 내비게이션 키로 바꿔 보내므로(fn+← = Home),
    /// 이벤트 탭이 보는 형태로 맞춰 저장한다. 그 외 fn 조합(fn+F 등)은 변환 대상이
    /// 없으므로 fn을 남겨둔다 — 남겨두면 탭의 조합과 절대 일치하지 않아
    /// 인벤토리에는 보이되 탐침에서 거짓 매칭을 만들지 않는다.
    static let fnArrowToNavigation: [UInt16: UInt16] = [
        123: 115,   // ← → Home
        124: 119,   // → → End
        126: 116,   // ↑ → Page Up
        125: 121,   // ↓ → Page Down
    ]

    static func combo(keyCode: UInt16?, modifier: UInt64) -> KeyCombo? {
        guard let keyCode else { return nil }
        var mods = Modifiers(tableMask: modifier)
        var key = keyCode
        if mods.contains(.function), let navKey = fnArrowToNavigation[keyCode] {
            key = navKey
            mods.remove(.function)
        }
        return KeyCombo(keyCode: key, modifiers: mods)
    }

    // MARK: - 표시명
    //
    // 시스템 표의 이름은 41개 언어 전부 영어(DO_NOT_LOCALIZE)라 직접 옮긴다.
    // 여기 없는 ID는 시스템의 영문명을 그대로 쓴다. 다국어 지원 시 이 맵이
    // 언어별 카탈로그로 옮겨갈 자리다.
    static let displayNames: [Int: String] = [
        7: "메뉴 막대로 초점 이동",
        8: "Dock으로 초점 이동",
        9: "활성 또는 다음 윈도우로 초점 이동",
        10: "윈도우 도구 막대로 초점 이동",
        11: "플로팅 윈도우로 초점 이동",
        12: "전체 키보드 접근 켜기/끄기",
        13: "Tab 초점 이동 방식 변경",
        15: "화면 확대/축소 켜기/끄기",
        17: "확대",
        19: "축소",
        21: "흑백 반전",
        23: "이미지 부드럽게 켜기/끄기",
        25: "대비 높이기",
        26: "대비 낮추기",
        27: "다음 윈도우로 초점 이동",
        28: "전체 화면 스크린샷 저장",
        29: "전체 화면 스크린샷 복사",
        30: "영역 스크린샷 저장",
        31: "영역 스크린샷 복사",
        32: "모든 윈도우 (Mission Control)",
        33: "응용 프로그램 윈도우",
        36: "데스크탑 보기",
        52: "Dock 자동 숨기기 전환",
        53: "디스플레이 밝기 낮추기",
        54: "디스플레이 밝기 높이기",
        57: "상태 메뉴로 초점 이동",
        59: "VoiceOver 켜기/끄기",
        60: "이전 입력 소스 선택",
        61: "입력 메뉴의 다음 소스 선택",
        64: "Spotlight 검색",
        65: "Finder 검색 윈도우",
        79: "왼쪽 Space로 이동",
        81: "오른쪽 Space로 이동",
        98: "도움말 메뉴 표시",
        156: "트랙패드 손글씨 표시/가리기",
        159: "컨텍스트 메뉴 표시",
        160: "앱 보기 (Launchpad)",
        162: "손쉬운 사용 제어 표시",
        163: "알림 센터 표시",
        175: "방해금지 모드",
        179: "초점 따라가기 켜기/끄기",
        181: "Touch Bar 스크린샷 저장",
        182: "Touch Bar 스크린샷 복사",
        184: "스크린샷 및 화면 기록 옵션",
        190: "빠른 메모",
        215: "실시간 자막 켜기/끄기",
        216: "전사 일시정지/재개",
        217: "입력하여 말하기 켜기/끄기",
        218: "컴퓨터 오디오/마이크 전사 전환",
        219: "화면에 유지 켜기/끄기",
        222: "스테이지 매니저",
        223: "발표자 오버레이(크게) 켜기/끄기",
        224: "발표자 오버레이(작게) 켜기/끄기",
        225: "실시간 말하기 켜기/끄기",
        226: "표시 여부 전환",
        227: "말하기 일시정지/재개",
        228: "말하기 취소",
        229: "문구 가리기/표시",
        230: "선택 항목 말하기 켜기/끄기",
        231: "포인터 아래 항목 말하기 켜기/끄기",
        232: "입력 피드백 켜기/끄기",
        233: "최소화",
        235: "확대/축소 (윈도우)",
        237: "채우기",
        238: "가운데",
        239: "이전 크기로 복귀",
        240: "화면 왼쪽 절반 타일",
        241: "화면 오른쪽 절반 타일",
        242: "화면 위쪽 절반 타일",
        243: "화면 아래쪽 절반 타일",
        244: "왼쪽 위 1/4 타일",
        245: "오른쪽 위 1/4 타일",
        246: "왼쪽 아래 1/4 타일",
        247: "오른쪽 아래 1/4 타일",
        248: "좌우로 정렬",
        249: "우좌로 정렬",
        250: "위아래로 정렬",
        251: "아래위로 정렬",
        256: "4분할로 정렬",
        257: "전체 화면 타일 (왼쪽)",
        258: "전체 화면 타일 (오른쪽)",
        260: "게임 오버레이",
    ]
}
