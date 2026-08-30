#if DEBUG_CAPTURE
import AppKit
import SwiftUI
import Engine

/// `--capture <dir>`로 실행하면 주요 화면을 PNG로 렌더링하고 끝낸다.
///
/// 번역이 화면에서 잘리는지, RTL 언어에서 배치가 뒤집히는지는 카탈로그 검사로 알 수 없다.
/// 키가 전부 있고 포맷 지정자가 맞아도 버튼은 잘린다 — 실제로 7개 언어가 그랬다.
///
/// `ImageRenderer`가 아니라 오프스크린 창에 올려 그린다. `ImageRenderer`는 `onAppear`를
/// 실행하지 않아 근거 목록(등장 애니메이션으로 채워진다)이 비어 있는 채로 찍혔다.
/// 임시 도구이며 DEBUG_CAPTURE 없이는 컴파일되지 않는다.
enum CaptureMode {
    @MainActor static func run(outDir: String) {
        let lang = Bundle.main.preferredLocalizations.first ?? "?"
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()

        shoot(name: "verdict", width: 360, view: AnyView(root(
            combo: KeyCombo(keyCode: 49, modifiers: [.command]), verdict: sampleVerdict)),
            lang: lang, outDir: outDir)


        // 시스템 소유자 판정은 "Open Keyboard Settings"라는 더 긴 버튼을 낸다 —
        // README 스크린샷에서 영어인데도 "Open Keyboard..."로 잘려 있었다.
        shoot(name: "verdict-system", width: 360, view: AnyView(root(
            combo: KeyCombo(keyCode: 21, modifiers: [.command, .shift]),
            verdict: .confirmed(.system(feature: "Save picture of selected area as a file"), [
                Evidence(source: .systemHotkeys,
                         owner: .system(feature: "Save picture of selected area as a file"),
                         confidence: .certain,
                         reason: .systemHotkey(id: 30, combo: "\u{21E7}\u{2318}4")),
            ]))), lang: lang, outDir: outDir)


        shoot(name: "permission", width: 360, view: AnyView(
            PermissionView().environmentObject(ProbeSession())), lang: lang, outDir: outDir)

        // 인벤토리는 실제로 쓰는 창 크기로 그린다 — 높이를 fittingSize에 맡기면 List가
        // 잘려 푸터가 마지막 행과 겹쳐 보인다(창 크기 문제이지 레이아웃 결함이 아니다).
        shoot(name: "inventory", width: 900, view: AnyView(InventoryWindow()),
              lang: lang, outDir: outDir, settle: 1.5, height: 600)
    }

    /// 실제 메뉴바 팝오버 그대로 — 판정 화면에 푸터 메뉴까지 붙는다.
    /// 세션 상태를 직접 넣어 탐침 없이 결과 화면을 띄운다.
    @MainActor private static func root(combo: KeyCombo, verdict: Verdict) -> some View {
        let session = ProbeSession()
        session.state = .result(combo, verdict)
        return RootView().environmentObject(session)
    }

    /// 소유자 셋짜리 contested — 목록 조립과 가장 긴 문장, 근거 4행을 한 화면에서 본다.
    private static var sampleVerdict: Verdict {
        let owners: [Owner] = [
            .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"),
            .app(bundleID: "com.raycast.macos", name: "Raycast", action: "toggle"),
            .system(feature: "Show Spotlight search"),
        ]
        return .contested(owners, [
            Evidence(source: .systemHotkeys, owner: owners[2], confidence: .certain,
                     reason: .systemHotkey(id: 64, combo: "⌘Space")),
            Evidence(source: .knownAppParser(appName: "Maccy"), owner: owners[0], confidence: .high,
                     reason: .knownApp(app: "Maccy", action: "popup", combo: "⌘Space", isRunning: true)),
            Evidence(source: .heuristicScan, owner: owners[1], confidence: .medium,
                     reason: .scanPattern(app: "Raycast", action: "toggle", combo: "⌘Space")),
            Evidence(source: .reaction, owner: owners[1], confidence: .medium,
                     reason: .reaction(app: "Raycast", milliseconds: 120,
                                       signals: [.newWindows(count: 1), .becameFrontmost])),
        ])
    }

    @MainActor private static func shoot(name: String, width: CGFloat, view: AnyView,
                                         lang: String, outDir: String, settle: TimeInterval = 0.8,
                                         height: CGFloat? = nil) {
        // -AppleLanguages는 CFBundle의 언어 협상만 바꾼다 — AppKit의 레이아웃 방향은
        // 따라오지 않아(NSApp.userInterfaceLayoutDirection이 LTR로 남는다) 아랍어가 좌우
        // 반전되지 않은 채 찍혔다. 실제 아랍어 환경에서 보게 될 화면을 그리려면 방향을
        // 명시해야 한다. 이것은 캡처 도구의 보정이며, 앱 자체는 시스템 방향을 따른다.
        let rtl = Locale.characterDirection(forLanguage: lang) == .rightToLeft
        let host = NSHostingView(rootView: view
            .frame(width: width)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight))
        host.userInterfaceLayoutDirection = rtl ? .rightToLeft : .leftToRight
        host.frame = NSRect(x: 0, y: 0, width: width, height: height ?? host.fittingSize.height)
        // borderless 창은 안전 영역이 잡히지 않아 safeAreaInset(푸터)이 리스트와 겹쳐 보인다.
        // 실제 창과 같은 스타일로 띄워야 레이아웃이 앱에서와 동일하게 계산된다.
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled, .resizable],
                              backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        // onAppear와 계단식 등장 애니메이션이 끝날 시간을 준다.
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        if height == nil { host.frame.size.height = host.fittingSize.height }
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            FileHandle.standardError.write("렌더 실패 \(lang)/\(name)\n".data(using: .utf8)!); return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)-\(lang).png"))
        print("\(lang)/\(name): \(Int(host.bounds.width))x\(Int(host.bounds.height))")
        window.orderOut(nil)
    }
}
#endif
