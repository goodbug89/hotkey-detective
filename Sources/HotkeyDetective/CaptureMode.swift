#if DEBUG_CAPTURE
import AppKit
import SwiftUI
import Engine

/// `--capture <dir>`로 실행하면 판정 화면을 PNG로 렌더링하고 끝낸다.
/// 번역이 화면에서 잘리는지, RTL 언어에서 배치가 뒤집히는지는 문자열 검사로는
/// 알 수 없다 — 실제로 그려봐야 한다. 임시 도구이며 배포 빌드에는 들어가지 않는다.
enum CaptureMode {
    @MainActor static func run(outDir: String) {
        let lang = Bundle.main.preferredLocalizations.first ?? "?"
        // 소유자 셋짜리 contested — ListFormatter 목록과 가장 긴 문장을 동시에 본다.
        let owners: [Owner] = [
            .app(bundleID: "org.p0deje.Maccy", name: "Maccy", action: "popup"),
            .app(bundleID: "com.raycast.macos", name: "Raycast", action: "toggle"),
            .system(feature: "Show Spotlight search"),
        ]
        let evidence: [Evidence] = [
            Evidence(source: .systemHotkeys, owner: owners[2], confidence: .certain,
                     reason: .systemHotkey(id: 64, combo: "⌘Space")),
            Evidence(source: .knownAppParser(appName: "Maccy"), owner: owners[0], confidence: .high,
                     reason: .knownApp(app: "Maccy", action: "popup", combo: "⌘Space", isRunning: true)),
            Evidence(source: .heuristicScan, owner: owners[1], confidence: .medium,
                     reason: .scanPattern(app: "Raycast", action: "toggle", combo: "⌘Space")),
            Evidence(source: .reaction, owner: owners[1], confidence: .medium,
                     reason: .reaction(app: "Raycast", milliseconds: 120, signals: [.newWindows(count: 1), .becameFrontmost])),
        ]
        let view = VerdictView(combo: KeyCombo(keyCode: 49, modifiers: [.command]),
                               verdict: .contested(owners, evidence))
            .environmentObject(ProbeSession())
            .frame(width: 360)
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("렌더링 실패: \(lang)\n".data(using: .utf8)!); exit(1)
        }
        try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(lang).png"))
        let rtl = NSApp.userInterfaceLayoutDirection == .rightToLeft
        print("\(lang): \(Int(image.size.width))x\(Int(image.size.height)) layoutDirection=\(rtl ? "RTL" : "LTR")")
    }
}
#endif
