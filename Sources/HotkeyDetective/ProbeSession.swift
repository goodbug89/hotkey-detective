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
    private var generation = 0

    init() { refreshPermission() }

    var resolvers: [Resolver] {
        [SystemHotkeyResolver(),
         CarbonOccupancyResolver(registrar: CarbonHotKeyRegistrar()),
         ReactionResolver()] + KnownApps.all(running: WorkspaceRunningApps())
    }

    func refreshPermission() {
        if AccessibilityGate.isTrusted(prompt: false) {
            // 권한이 실제로 생겼으면 제한 모드를 벗어난다.
            limitedMode = false
            stopPermissionPoll()
            if case .needsPermission = state { state = .idle }
        } else if limitedMode {
            stopPermissionPoll()
            if case .needsPermission = state { state = .idle }
        } else {
            switch state {
            case .idle, .needsPermission: state = .needsPermission
            default: break
            }
            startPermissionPoll()
        }
    }

    /// 사용자가 시스템 설정에서 권한을 켜는 순간을 감지하기 위한 폴링
    private func startPermissionPoll() {
        guard permissionPoll == nil else { return }
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    private func stopPermissionPoll() {
        permissionPoll?.invalidate(); permissionPoll = nil
    }

    func requestPermission() {
        _ = AccessibilityGate.isTrusted(prompt: true)
        AccessibilityGate.openSettings()
        refreshPermission()
    }

    func openInputMonitoringSettings() {
        AccessibilityGate.openInputMonitoringSettings()
        refreshPermission()
    }

    func useLimitedMode() { limitedMode = true; refreshPermission() }

    func startListening() {
        generation += 1
        let gen = generation
        before = SystemSnapshot.capture()
        state = .listening
        listener.start { [weak self] outcome in
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                switch outcome {
                case .combo(let c): self.resolve(c, withProbe: true)
                case .cancelled, .timedOut: self.state = .idle
                case .tapFailed:
                    // 탭 생성 실패 = 손쉬운 사용/입력 모니터링 중 하나가 빠진 상태.
                    self.limitedMode = false
                    self.state = .needsPermission
                    self.startPermissionPoll()
                }
            }
        }
    }

    func cancelListening() { generation += 1; listener.stop(); state = .idle }

    func probe(manual combo: KeyCombo) { generation += 1; resolve(combo, withProbe: false) }

    func reset() { generation += 1; state = .idle }

    private func resolve(_ combo: KeyCombo, withProbe: Bool) {
        let gen = generation
        state = .resolving(combo)
        let run: (ProbeSnapshot?) -> Void = { [weak self] snap in
            guard let self else { return }
            let evidence = self.resolvers.flatMap { $0.resolve(combo, probe: snap) }
            self.state = .result(combo, VerdictBuilder.build(evidence))
        }
        guard withProbe, let before else { run(nil); return }
        let start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reactionDelay) { [weak self] in
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                let after = SystemSnapshot.capture()
                run(ProbeSnapshot(before: before, after: after, elapsed: Date().timeIntervalSince(start), selfPID: getpid()))
            }
        }
    }
}
