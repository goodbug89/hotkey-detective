import Foundation

public struct Modifiers: OptionSet, Hashable, Codable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control  = Modifiers(rawValue: 1 << 0)
    public static let option   = Modifiers(rawValue: 1 << 1)
    public static let shift    = Modifiers(rawValue: 1 << 2)
    public static let command  = Modifiers(rawValue: 1 << 3)
    public static let function = Modifiers(rawValue: 1 << 4)

    // CGEventFlags / NSEvent.ModifierFlags / symbolichotkeys 마스크 (동일 비트)
    static let cgShift: UInt64 = 1 << 17, cgControl: UInt64 = 1 << 18
    static let cgOption: UInt64 = 1 << 19, cgCommand: UInt64 = 1 << 20, cgFunction: UInt64 = 1 << 23

    // Carbon: cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096
    static let cbCommand: UInt32 = 256, cbShift: UInt32 = 512, cbOption: UInt32 = 2048, cbControl: UInt32 = 4096

    /// CGEventFlags에서 수정자를 읽는다.
    /// 주의: macOS는 화살표/F키 keyDown마다 fn 비트(1<<23)를 함께 세운다. 반면 symbolichotkeys
    /// 기본값 테이블과 Rectangle/Maccy 설정 파일은 fn 없이 조합을 저장하므로, 여기서 fn을
    /// 넣으면 `⌃←` 같은 조합이 영원히 매칭되지 않는다. 따라서 fn 비트는 무시한다.
    /// (`.function`은 표시용으로 남아 있으며 CG 플래그에서는 만들어지지 않는다.)
    public init(cgFlags: UInt64) {
        var m: Modifiers = []
        if cgFlags & Self.cgControl != 0 { m.insert(.control) }
        if cgFlags & Self.cgOption != 0 { m.insert(.option) }
        if cgFlags & Self.cgShift != 0 { m.insert(.shift) }
        if cgFlags & Self.cgCommand != 0 { m.insert(.command) }
        self = m
    }

    /// 시스템 단축키 표(DefaultShortcutsTable.xml)의 마스크를 읽을 때 쓴다.
    /// `init(cgFlags:)`와 달리 fn 비트를 **보존**한다 — 표에서 fn은 실제 의미를 갖는다
    /// (⌃fn← 타일링 vs ⌃← Space 이동). 이벤트 탭 쪽 fn은 화살표/F키에 자동으로 붙어
    /// 신뢰할 수 없으므로 거기서는 계속 버린다.
    public init(tableMask: UInt64) {
        var m = Modifiers(cgFlags: tableMask)
        if tableMask & Self.cgFunction != 0 { m.insert(.function) }
        self = m
    }

    public var cgFlags: UInt64 {
        var f: UInt64 = 0
        if contains(.control) { f |= Self.cgControl }
        if contains(.option) { f |= Self.cgOption }
        if contains(.shift) { f |= Self.cgShift }
        if contains(.command) { f |= Self.cgCommand }
        if contains(.function) { f |= Self.cgFunction }
        return f
    }

    public init(carbon: UInt32) {
        var m: Modifiers = []
        if carbon & Self.cbControl != 0 { m.insert(.control) }
        if carbon & Self.cbOption != 0 { m.insert(.option) }
        if carbon & Self.cbShift != 0 { m.insert(.shift) }
        if carbon & Self.cbCommand != 0 { m.insert(.command) }
        self = m
    }

    public var carbon: UInt32 {
        var f: UInt32 = 0
        if contains(.control) { f |= Self.cbControl }
        if contains(.option) { f |= Self.cbOption }
        if contains(.shift) { f |= Self.cbShift }
        if contains(.command) { f |= Self.cbCommand }
        return f
    }

    /// 표시 순서: ⌃⌥⇧⌘, fn은 맨 앞
    public var glyphs: String {
        var s = ""
        if contains(.function) { s += "fn" }
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

public struct KeyCombo: Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var display: String { modifiers.glyphs + KeyCodeNames.name(for: keyCode) }
}
