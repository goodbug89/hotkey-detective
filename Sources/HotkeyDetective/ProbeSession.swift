import AppKit
import Combine
import Engine
import Probe

enum ProbeState {
    case needsPermission, idle, listening
    case resolving(KeyCombo)
    case result(KeyCombo, Verdict)
}

@MainActor
final class ProbeSession: ObservableObject {
    @Published var state: ProbeState = .idle
    @Published var limitedMode = false

    static let reactionDelay: TimeInterval = 0.3
    private let listener = EventTapListener(timeout: 15)
    private var permissionPoll: Timer?
    private var before: SystemState?

    init() { refreshPermission() }

    var resolvers: [Resolver] {
        [SystemHotkeyResolver(),
         CarbonOccupancyResolver(registrar: CarbonHotKeyRegistrar()),
         ReactionResolver()] + KnownApps.all(running: WorkspaceRunningApps())
    }

    func refreshPermission() {
        if AccessibilityGate.isTrusted(prompt: false) || limitedMode {
            permissionPoll?.invalidate(); permissionPoll = nil
            if case .needsPermission = state { state = .idle }
        } else {
            state = .needsPermission
            if permissionPoll == nil {
                permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.refreshPermission() }
                }
            }
        }
    }

    func requestPermission() {
        _ = AccessibilityGate.isTrusted(prompt: true)
        AccessibilityGate.openSettings()
    }

    func useLimitedMode() { limitedMode = true; refreshPermission() }

    func startListening() {
        before = SystemSnapshot.capture()
        state = .listening
        listener.start { [weak self] outcome in
            Task { @MainActor in
                guard let self else { return }
                switch outcome {
                case .combo(let c): self.resolve(c, withProbe: true)
                case .cancelled, .timedOut: self.state = .idle
                case .tapFailed: self.limitedMode = false; self.state = .needsPermission
                }
            }
        }
    }

    func cancelListening() { listener.stop(); state = .idle }

    func probe(manual combo: KeyCombo) { resolve(combo, withProbe: false) }

    func reset() { state = .idle }

    private func resolve(_ combo: KeyCombo, withProbe: Bool) {
        state = .resolving(combo)
        let run: (ProbeSnapshot?) -> Void = { [weak self] snap in
            guard let self else { return }
            let evidence = self.resolvers.flatMap { $0.resolve(combo, probe: snap) }
            self.state = .result(combo, VerdictBuilder.build(evidence))
        }
        guard withProbe, let before else { run(nil); return }
        let start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reactionDelay) {
            Task { @MainActor in
                let after = SystemSnapshot.capture()
                run(ProbeSnapshot(before: before, after: after, elapsed: Date().timeIntervalSince(start), selfPID: getpid()))
            }
        }
    }
}
