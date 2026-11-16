import Testing
@testable import SweepCore

// Inputs are synthetic; no trackpad needed.

private func swipe(_ r: inout GestureRecognizer, dx: Double, dy: Double, count: Int,
                   start: Double = 0, step: Double = 0.01, begin: Bool = true) -> [RecognizerOutput] {
    var out: [RecognizerOutput] = []
    for i in 0..<count {
        let phase: TouchPhase = (begin && i == 0) ? .began : .changed
        out += r.handle(.scroll(dx: dx, dy: dy, phase: phase, time: start + Double(i) * step))
    }
    return out
}

private func steps(_ out: [RecognizerOutput]) -> [Primitive] {
    out.compactMap { if case .step(let p) = $0 { return p } else { return nil } }
}

@Suite struct RecognizerConfigTests {
    @Test(arguments: [(1, 8, 25, 16, 75, 0.10), (2, 6, 15, 12, 45, 0.08),
                      (3, 4, 10, 8, 30, 0.06), (4, 2, 5, 4, 15, 0.04)])
    func sensitivityTable(slider: Int, minSwipe: Int, swipeWindow: Int,
                          minPinch: Int, pinchWindow: Int, rest: Double) {
        let c = RecognizerConfig(sensitivity: slider)
        #expect(c.minSwipeEvents == minSwipe)
        #expect(c.swipeWindow == swipeWindow)
        #expect(c.minPinchEvents == minPinch)
        #expect(c.pinchWindow == pinchWindow)
        #expect(abs(c.restDelay - rest) < 1e-9)
    }

    @Test func sensitivityIsClamped() {
        #expect(RecognizerConfig(sensitivity: 0).minSwipeEvents == 8)
        #expect(RecognizerConfig(sensitivity: 9).minSwipeEvents == 2)
    }

    @Test func cancelTimeoutFromMilliseconds() {
        #expect(RecognizerConfig(sensitivity: 3, cancelTimeoutMs: 800).cancelTimeout == 0.8)
    }
}

@Suite struct FingerMotionTests {
    @Test func naturalScrolling() {
        // Natural scrolling on: deltas follow the fingers on X, Y grows downward.
        let m = FingerMotion(scrollDeltaX: 5, scrollDeltaY: 3, invertedFromDevice: true)
        #expect(m.dx == 5 && m.dy == -3)
    }

    @Test func classicScrolling() {
        let m = FingerMotion(scrollDeltaX: 5, scrollDeltaY: 3, invertedFromDevice: false)
        #expect(m.dx == -5 && m.dy == 3)
    }
}

@Suite struct SwipeTests {
    @Test func noStepBeforeMinEvents() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))  // min 4
        #expect(steps(swipe(&r, dx: 10, dy: 0, count: 3)).isEmpty)
    }

    @Test(arguments: [(10.0, 0.0, Direction.right), (-10, 0, .left), (0, 10, .up), (0, -10, .down)])
    func dominantAxisPicksDirection(dx: Double, dy: Double, expected: Direction) {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        #expect(steps(swipe(&r, dx: dx, dy: dy, count: 4)) == [.swipe(expected)])
    }

    @Test func diagonalUsesLargerAxis() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        #expect(steps(swipe(&r, dx: 3, dy: -7, count: 4)) == [.swipe(.down)])
    }

    @Test func repeatedDirectionIsReportedOnce() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        #expect(steps(swipe(&r, dx: 10, dy: 0, count: 20)) == [.swipe(.right)])
    }

    @Test func directionChangeIsReported() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 4))  // window 5
        var out = swipe(&r, dx: 10, dy: 0, count: 5)
        out += swipe(&r, dx: 0, dy: 10, count: 10, start: 0.05, begin: false)
        #expect(steps(out) == [.swipe(.right), .swipe(.up)])
    }

    @Test func windowSumsOnlyRecentEvents() {
        // Window 5 at slider 4: after 5 upward events the old rightward motion no longer counts.
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 4))
        var out = swipe(&r, dx: 50, dy: 0, count: 2)
        out += swipe(&r, dx: 0, dy: 5, count: 5, start: 0.02, begin: false)
        #expect(steps(out).last == .swipe(.up))
    }

    @Test func zeroMotionGivesNoStep() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        #expect(steps(swipe(&r, dx: 0, dy: 0, count: 8)).isEmpty)
    }

    @Test func eventsWithoutSessionAreIgnored() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        #expect(steps(swipe(&r, dx: 10, dy: 0, count: 8, begin: false)).isEmpty)
        #expect(!r.isActive)
    }
}

@Suite struct PauseAndRepeatTests {
    @Test func restAfterSwipeEmitsPauseAndAllowsRepeat() {
        let c = RecognizerConfig(sensitivity: 3)
        var r = GestureRecognizer(config: c)
        var out = swipe(&r, dx: 10, dy: 0, count: 6)       // last event at t=0.05
        #expect(r.nextDeadline != nil)
        out += r.tick(now: 0.05 + c.restDelay + 0.001)
        out += swipe(&r, dx: 10, dy: 0, count: 6, start: 0.2, begin: false)
        #expect(steps(out) == [.swipe(.right), .pause, .swipe(.right)])
    }

    @Test func noPauseBeforeEnoughEvents() {
        let c = RecognizerConfig(sensitivity: 3)
        var r = GestureRecognizer(config: c)
        var out = swipe(&r, dx: 10, dy: 0, count: 2)
        out += r.tick(now: 1.0 - 0.5)
        #expect(!steps(out).contains(.pause))
    }

    @Test func tickBeforeDeadlineDoesNothing() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        _ = swipe(&r, dx: 10, dy: 0, count: 6)
        #expect(r.tick(now: 0.051).isEmpty)
    }
}

@Suite struct HoldTapPinchTests {
    @Test func restingFingersGiveHoldWhenEnabled() {
        let c = RecognizerConfig(sensitivity: 3, tapHoldEnabled: true)
        var r = GestureRecognizer(config: c)
        _ = r.handle(.scroll(dx: 0, dy: 0, phase: .mayBegin, time: 0))
        #expect(r.isActive)
        #expect(steps(r.tick(now: c.restDelay + 0.001)) == [.hold])
    }

    @Test func noHoldWhenDisabled() {
        let c = RecognizerConfig(sensitivity: 3, tapHoldEnabled: false)
        var r = GestureRecognizer(config: c)
        _ = r.handle(.scroll(dx: 0, dy: 0, phase: .mayBegin, time: 0))
        #expect(steps(r.tick(now: 1)).isEmpty)
    }

    @Test func smartMagnifyIsTap() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        #expect(steps(r.handle(.smartMagnify(time: 0))) == [.tap])
        #expect(r.isActive)
    }

    @Test func pinchOutAndIn() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))  // min 8
        var out: [RecognizerOutput] = []
        for i in 0..<8 {
            out += r.handle(.magnify(0.01, phase: i == 0 ? .began : .changed, time: Double(i) * 0.01))
        }
        #expect(steps(out) == [.pinchOut])
        var r2 = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        out = []
        for i in 0..<8 {
            out += r2.handle(.magnify(-0.01, phase: i == 0 ? .began : .changed, time: Double(i) * 0.01))
        }
        #expect(steps(out) == [.pinchIn])
    }

    @Test func tinyMagnificationIsIgnored() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 4))
        var out: [RecognizerOutput] = []
        for i in 0..<20 {
            out += r.handle(.magnify(0.002, phase: i == 0 ? .began : .changed, time: Double(i) * 0.01))
        }
        #expect(steps(out).isEmpty)
    }
}

@Suite struct EndAndCancelTests {
    @Test func endedPhaseEndsSessionWithAllSteps() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        var out = swipe(&r, dx: 10, dy: 0, count: 5)
        out += r.handle(.scroll(dx: 0, dy: 0, phase: .ended, time: 0.1))
        #expect(out.last == .ended([.swipe(.right)]))
        #expect(!r.isActive)
    }

    @Test func cancelTimeoutCancels() {
        let c = RecognizerConfig(sensitivity: 3, cancelTimeoutMs: 800)
        var r = GestureRecognizer(config: c)
        _ = r.handle(.scroll(dx: 0, dy: 0, phase: .mayBegin, time: 0))
        let out = r.tick(now: 0.81)
        #expect(out.contains(.cancelled))
        #expect(!r.isActive)
    }

    @Test func explicitCancel() {
        var r = GestureRecognizer(config: RecognizerConfig(sensitivity: 3))
        _ = swipe(&r, dx: 10, dy: 0, count: 5)
        #expect(r.cancel() == [.cancelled])
        #expect(!r.isActive)
        #expect(r.cancel().isEmpty)
    }
}
