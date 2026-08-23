import CoreGraphics
import Foundation
import Engine

public final class EventTapListener {
    public enum Outcome { case combo(KeyCombo), cancelled, timedOut, tapFailed }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timeoutTimer: Timer?
    private var handler: ((Outcome) -> Void)?
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 15) { self.timeout = timeout }

    public func start(_ handler: @escaping (Outcome) -> Void) {
        stop()
        self.handler = handler
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .listenOnly, eventsOfInterest: CGEventMask(mask),
                                          callback: { _, type, event, refcon in
                                              let me = Unmanaged<EventTapListener>.fromOpaque(refcon!).takeUnretainedValue()
                                              me.handle(type: type, event: event)
                                              return Unmanaged.passUnretained(event)
                                          }, userInfo: selfPtr) else {
            finish(.tapFailed); return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.finish(.timedOut)
        }
    }

    public func stop() {
        timeoutTimer?.invalidate(); timeoutTimer = nil
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        tap = nil; source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 53 { finish(.cancelled); return }
            let mods = Modifiers(cgFlags: event.flags.rawValue).subtracting(.function)
            guard !mods.isEmpty else { return }
            let full = Modifiers(cgFlags: event.flags.rawValue)
            finish(.combo(KeyCombo(keyCode: keyCode, modifiers: full)))
        default: break
        }
    }

    private func finish(_ outcome: Outcome) {
        let h = handler
        handler = nil
        stop()
        DispatchQueue.main.async { h?(outcome) }
    }
}
