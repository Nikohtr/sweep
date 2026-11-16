/// Turns a stream of trackpad events into gesture steps.
///
/// The recognizer is a plain value type:
/// the app feeds it events and calls `tick(now:)` when `nextDeadline` passes.

public enum Direction: Sendable, Equatable, CaseIterable {
    case left, right, up, down
}

/// One recognized piece of a gesture.
public enum Primitive: Sendable, Equatable {
    case swipe(Direction)
    case pinchIn
    case pinchOut
    case hold
    case tap
    /// The fingers stopped moving for the rest delay. The same direction can count again after this.
    case pause
}

public enum TouchPhase: Sendable, Equatable {
    case mayBegin, began, changed, ended, cancelled
}

/// Input in finger space: +dx = fingers move right, +dy = fingers move up.
public enum InputEvent: Sendable, Equatable {
    case scroll(dx: Double, dy: Double, phase: TouchPhase, time: Double)
    case magnify(Double, phase: TouchPhase, time: Double)
    case smartMagnify(time: Double)

    /// When the event happened (event timestamp, seconds).
    public var time: Double {
        switch self {
        case .scroll(_, _, _, let t), .magnify(_, _, let t), .smartMagnify(let t): return t
        }
    }
}

public enum RecognizerOutput: Sendable, Equatable {
    case step(Primitive)
    /// The fingers left the trackpad. Carries every step of the session.
    case ended([Primitive])
    case cancelled
}

/// Converts NSEvent scroll deltas to finger motion.
public struct FingerMotion: Sendable, Equatable {
    public let dx: Double
    public let dy: Double

    public init(scrollDeltaX: Double, scrollDeltaY: Double, invertedFromDevice: Bool) {
        // With natural scrolling the content follows the fingers; AppKit's Y axis points down.
        if invertedFromDevice {
            dx = scrollDeltaX
            dy = -scrollDeltaY
        } else {
            dx = -scrollDeltaX
            dy = scrollDeltaY
        }
    }
}

public struct RecognizerConfig: Sendable, Equatable {
    public var minSwipeEvents: Int
    public var swipeWindow: Int
    public var minPinchEvents: Int
    public var pinchWindow: Int
    /// Seconds without new events before a pause (after motion) or a hold (resting fingers).
    public var restDelay: Double
    /// Seconds without new events before the gesture is dropped.
    public var cancelTimeout: Double
    public var tapHoldEnabled: Bool
    /// Magnify events at or below this size are noise.
    public var magnifyFloor: Double = 0.002

    /// - Parameter sensitivity: the settings slider value, 1 (least) to 4 (most).
    public init(sensitivity: Int, cancelTimeoutMs: Int = 800, tapHoldEnabled: Bool = true) {
        let i = min(max(sensitivity, 1), 4) - 1
        minSwipeEvents = 8 - 2 * i
        swipeWindow = [25, 15, 10, 5][i]
        minPinchEvents = 16 - 4 * i
        pinchWindow = [75, 45, 30, 15][i]
        restDelay = [0.10, 0.08, 0.06, 0.04][i]
        cancelTimeout = Double(cancelTimeoutMs) / 1000
        self.tapHoldEnabled = tapHoldEnabled
    }
}

public struct GestureRecognizer: Sendable {
    public var config: RecognizerConfig
    public private(set) var isActive = false
    public private(set) var steps: [Primitive] = []

    private enum RestKind { case pause, hold }

    private var eventCount = 0
    private var xs: [Double] = []
    private var ys: [Double] = []
    private var mags: [Double] = []
    private var lastMotion: Primitive?
    private var restDeadline: Double?
    private var restKind: RestKind = .pause
    private var cancelDeadline: Double?

    public init(config: RecognizerConfig) {
        self.config = config
    }

    /// The earliest time `tick(now:)` has work to do, if any.
    public var nextDeadline: Double? {
        [restDeadline, cancelDeadline].compactMap { $0 }.min()
    }

    public mutating func handle(_ event: InputEvent) -> [RecognizerOutput] {
        switch event {
        case let .scroll(dx, dy, phase, time):
            return handleScroll(dx: dx, dy: dy, phase: phase, time: time)
        case let .magnify(m, phase, time):
            return handleMagnify(m, phase: phase, time: time)
        case let .smartMagnify(time):
            if !isActive { start() }
            armCancel(time)
            return emit(.tap)
        }
    }

    /// Fires due timers.
    public mutating func tick(now: Double) -> [RecognizerOutput] {
        guard isActive else { return [] }
        if let c = cancelDeadline, now >= c {
            return cancel()
        }
        guard let r = restDeadline, now >= r else { return [] }
        restDeadline = nil
        switch restKind {
        case .hold:
            return config.tapHoldEnabled ? emit(.hold) : []
        case .pause:
            guard eventCount > minEventsForPause else { return [] }
            resetSamples()
            return emit(.pause)
        }
    }

    /// Drops the gesture in progress (Esc key or timeout).
    public mutating func cancel() -> [RecognizerOutput] {
        guard isActive else { return [] }
        reset()
        return [.cancelled]
    }

    // MARK: - Private

    private var minEventsForPause: Int {
        mags.isEmpty ? config.minSwipeEvents : config.minPinchEvents
    }

    private mutating func handleScroll(dx: Double, dy: Double, phase: TouchPhase, time: Double) -> [RecognizerOutput] {
        switch phase {
        case .mayBegin:
            if !isActive { start() }
            armRest(time, kind: .hold)
            armCancel(time)
            return []
        case .began, .changed:
            if phase == .began, !isActive { start() }
            guard isActive else { return [] }
            eventCount += 1
            xs.append(dx)
            ys.append(dy)
            armRest(time, kind: .pause)
            armCancel(time)
            guard eventCount >= config.minSwipeEvents,
                  let dir = Self.direction(dx: xs.suffix(config.swipeWindow).reduce(0, +),
                                           dy: ys.suffix(config.swipeWindow).reduce(0, +))
            else { return [] }
            return emitMotion(.swipe(dir))
        case .ended:
            return end()
        case .cancelled:
            // Fingers lifted without moving. Keep the session so a tap or hold can still finish it.
            return isActive ? end() : []
        }
    }

    private mutating func handleMagnify(_ m: Double, phase: TouchPhase, time: Double) -> [RecognizerOutput] {
        switch phase {
        case .ended:
            return end()
        case .cancelled:
            return isActive ? end() : []
        case .mayBegin, .began, .changed:
            if phase != .changed, !isActive { start() }
            guard isActive, abs(m) > config.magnifyFloor else { return [] }
            eventCount += 1
            mags.append(m)
            armRest(time, kind: .pause)
            armCancel(time)
            guard eventCount >= config.minPinchEvents else { return [] }
            let sum = mags.suffix(config.pinchWindow).reduce(0, +)
            return emitMotion(sum > 0 ? .pinchOut : .pinchIn)
        }
    }

    static func direction(dx: Double, dy: Double) -> Direction? {
        if dx == 0 && dy == 0 { return nil }
        if abs(dx) > abs(dy) { return dx > 0 ? .right : .left }
        return dy > 0 ? .up : .down
    }

    private mutating func emitMotion(_ p: Primitive) -> [RecognizerOutput] {
        guard p != lastMotion else { return [] }
        lastMotion = p
        return emit(p)
    }

    private mutating func emit(_ p: Primitive) -> [RecognizerOutput] {
        steps.append(p)
        return [.step(p)]
    }

    private mutating func end() -> [RecognizerOutput] {
        guard isActive else { return [] }
        let all = steps
        reset()
        return [.ended(all)]
    }

    private mutating func start() {
        reset()
        isActive = true
    }

    private mutating func armRest(_ time: Double, kind: RestKind) {
        restDeadline = time + config.restDelay
        restKind = kind
    }

    private mutating func armCancel(_ time: Double) {
        cancelDeadline = time + config.cancelTimeout
    }

    private mutating func resetSamples() {
        eventCount = 0
        xs.removeAll()
        ys.removeAll()
        mags.removeAll()
        lastMotion = nil
    }

    private mutating func reset() {
        resetSamples()
        isActive = false
        steps.removeAll()
        restDeadline = nil
        cancelDeadline = nil
    }
}
