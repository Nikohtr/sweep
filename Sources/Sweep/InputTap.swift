import AppKit
import ApplicationServices
import SweepCore

/// Listens to trackpad input through a session event tap and feeds `GestureRecognizer`.
///
/// Event kinds: key down (Esc cancels), flags changed, scroll wheel, gesture (type 29, which
/// arrives as magnify / smart magnify NSEvents). The tap is listen-only for now.
/// Where a gesture started and which window it acts on.
struct GestureContext {
    let origin: Origin
    let window: AXUIElement?
    /// Modifier keys held when the gesture started.
    let modifiers: ModifierKeys
    /// The app behind a Dock icon, for dock gestures.
    var app: NSRunningApplication? = nil
    /// Where the gesture started (global, top-left origin).
    var cursor: CGPoint = .zero
    /// The tab under the cursor, for tab gestures.
    var tab: AXUIElement? = nil
    /// The thumbnail title, for Mission Control gestures.
    var title: String? = nil
}

extension ModifierKeys {
    init(_ flags: NSEvent.ModifierFlags) {
        var k: ModifierKeys = []
        if flags.contains(.control) { k.insert(.control) }
        if flags.contains(.option) { k.insert(.option) }
        if flags.contains(.shift) { k.insert(.shift) }
        if flags.contains(.command) { k.insert(.command) }
        self = k
    }
}

@MainActor
final class InputTap {
    /// Called with each output, the context of the current gesture, and all steps so far.
    var onOutput: ((RecognizerOutput, GestureContext?, [Primitive]) -> Void)?
    /// Decides where a new gesture starts (global top-left cursor). Nil drops the gesture.
    var contextProvider: ((CGPoint, ModifierKeys) -> GestureContext?)?

    private(set) var recognizer: GestureRecognizer
    private(set) var context: GestureContext?
    /// Left mouse down / dragged / up with the global (top-left) location, for drag to unsnap.
    var onMouse: ((NSEvent.EventType, CGPoint, ModifierKeys) -> Void)?
    /// (fromMouse, held keys) → may this gesture start? Set by the app.
    var mousePolicy: ((Bool, ModifierKeys) -> Bool)?
    /// Drop scroll/pinch events while a gesture with a context is active. Restart the tap to apply.
    var activeListener = false
    /// Whether the running tap was made able to drop events.
    private(set) var tapIsActive = false
    /// "Disable Magic Mouse": only accept gesture input backed by trackpad touches.
    var disableMouse = false
    private var mouseFilter = MouseFilter()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: DispatchWorkItem?

    init(config: RecognizerConfig) {
        recognizer = GestureRecognizer(config: config)
    }

    var isRunning: Bool { tap != nil }

    /// Returns false when the tap cannot be made (usually: no Accessibility permission).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        tapIsActive = activeListener
        let gestureType: UInt64 = 29  // not in CGEventType
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << gestureType)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: activeListener ? .defaultTap : .listenOnly, eventsOfInterest: mask,
                                           callback: inputTapCallback, userInfo: refcon) else {
            return false
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src
        return true
    }

    func stop() {
        if let port = tap { CGEvent.tapEnable(tap: port, enable: false) }
        if let src = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        tap = nil
        source = nil
        timer?.cancel()
    }

    func updateConfig(_ config: RecognizerConfig) {
        recognizer.config = config
    }

    fileprivate func reenable() {
        if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
    }

    /// Handles one event; returns true when the event should be dropped (active tap only).
    fileprivate func receive(_ cgEvent: CGEvent) -> Bool {
        // Our own synthetic events (Space move, tab detach) must not start drag-to-unsnap or gestures.
        if cgEvent.getIntegerValueField(.eventSourceUserData) == SpaceMover.syntheticTag { return false }
        guard let event = NSEvent(cgEvent: cgEvent) else { return false }
        handle(event, cgEvent)
        let kind: EventBlockPolicy.Kind
        switch event.type {
        case .scrollWheel: kind = .scroll
        case .magnify: kind = .magnify
        case .smartMagnify: kind = .smartMagnify
        default: kind = .other
        }
        return tapIsActive && EventBlockPolicy.shouldBlock(kind: kind, activeListener: activeListener,
                                                           gestureActive: recognizer.isActive && context != nil)
    }

    private func handle(_ event: NSEvent, _ cgEvent: CGEvent) {
        let cursor = cgEvent.location
        if [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type) {
            onMouse?(event.type, cursor, ModifierKeys(event.modifierFlags))
            return
        }
        if event.type == .gesture {
            let touches = event.touches(matching: [.began, .moved, .stationary], in: nil).count
            mouseFilter.noteTouches(count: touches, time: event.timestamp)
            return
        }
        if [.scrollWheel, .magnify, .smartMagnify].contains(event.type),
           !mouseFilter.accepts(time: event.timestamp, disableMouse: disableMouse) {
            return
        }
        switch event.type {
        case .keyDown:
            if event.keyCode == 53, !event.isARepeat { deliver(recognizer.cancel()) }
        case .scrollWheel:
            // Only trackpad scrolls have a finger phase; mouse wheel ticks and momentum do not.
            let fingerPhase = Self.phase(event.phase)
            guard ScrollFilter.isFingerScroll(phase: fingerPhase, momentum: !event.momentumPhase.isEmpty),
                  let phase = fingerPhase else { return }
            let motion = FingerMotion(scrollDeltaX: event.scrollingDeltaX, scrollDeltaY: event.scrollingDeltaY,
                                      invertedFromDevice: event.isDirectionInvertedFromDevice)
            feed(.scroll(dx: motion.dx, dy: motion.dy, phase: phase, time: event.timestamp), cursor: cursor,
                 modifiers: ModifierKeys(event.modifierFlags))
        case .magnify:
            guard let phase = Self.phase(event.phase) else { return }
            feed(.magnify(event.magnification, phase: phase, time: event.timestamp), cursor: cursor,
                 modifiers: ModifierKeys(event.modifierFlags))
        case .smartMagnify:
            feed(.smartMagnify(time: event.timestamp), cursor: cursor, modifiers: ModifierKeys(event.modifierFlags))
        default:
            break
        }
    }

    /// Feeds one event. A new session only continues when the cursor is over a gesture area.
    private func feed(_ input: InputEvent, cursor: CGPoint, modifiers: ModifierKeys) {
        let wasActive = recognizer.isActive
        let outputs = recognizer.handle(input)
        if !wasActive, recognizer.isActive {
            // A gesture from a mouse (no trackpad fingers) only starts when the policy allows it.
            let fromMouse = mouseFilter.isMouse(time: input.time)
            if let allow = mousePolicy, !allow(fromMouse, modifiers) {
                _ = recognizer.cancel()
                scheduleTick()
                return
            }
            context = contextProvider?(cursor, modifiers)
            if context == nil {
                _ = recognizer.cancel()  // not a gesture area: let the event act normally
                scheduleTick()
                return
            }
        }
        deliver(outputs)
    }

    private func deliver(_ outputs: [RecognizerOutput]) {
        let steps = recognizer.steps
        outputs.forEach { output in
            if case .ended(let all) = output {
                onOutput?(output, context, all)
            } else {
                onOutput?(output, context, steps)
            }
        }
        scheduleTick()
    }

    private func scheduleTick() {
        timer?.cancel()
        guard let deadline = recognizer.nextDeadline else { return }
        let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.deliver(self.recognizer.tick(now: ProcessInfo.processInfo.systemUptime))
            }
        }
        timer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.001, execute: item)
    }

    static func phase(_ p: NSEvent.Phase) -> TouchPhase? {
        if p.contains(.mayBegin) { return .mayBegin }
        if p.contains(.began) { return .began }
        if p.contains(.changed) || p.contains(.stationary) { return .changed }
        if p.contains(.ended) { return .ended }
        if p.contains(.cancelled) { return .cancelled }
        return nil
    }
}

private func inputTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<InputTap>.fromOpaque(refcon).takeUnretainedValue()
    // The tap's run-loop source is on the main run loop, so this callback runs on the main thread.
    nonisolated(unsafe) let mainThreadEvent = event
    nonisolated(unsafe) var drop = false
    MainActor.assumeIsolated {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tap.reenable()
        } else {
            drop = tap.receive(mainThreadEvent)
        }
    }
    return drop ? nil : Unmanaged.passUnretained(event)
}
