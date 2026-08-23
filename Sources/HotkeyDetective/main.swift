import AppKit
import Engine
import Probe
let app = NSApplication.shared
print("trusted:", AccessibilityGate.isTrusted(prompt: true))
let before = SystemSnapshot.capture()
let l = EventTapListener()
print("지금 조합을 누르세요 (15초)")
l.start { outcome in
    guard case .combo(let c) = outcome else { print(outcome); exit(0) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        let after = SystemSnapshot.capture()
        let probe = ProbeSnapshot(before: before, after: after, elapsed: 0.3, selfPID: getpid())
        let resolvers: [Resolver] = [SystemHotkeyResolver(), CarbonOccupancyResolver(registrar: CarbonHotKeyRegistrar()),
                                     ReactionResolver()] + KnownApps.all(running: WorkspaceRunningApps())
        let ev = resolvers.flatMap { $0.resolve(c, probe: probe) }
        print(c.display, VerdictBuilder.build(ev))
        exit(0)
    }
}
app.run()
