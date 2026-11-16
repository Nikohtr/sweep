import Testing
@testable import SweepCore

/// The active event listener keeps the window under a gesture from also scrolling or zooming.
@Suite struct EventBlockTests {
    @Test(arguments: [EventBlockPolicy.Kind.scroll, .magnify, .smartMagnify])
    func blocksGestureInputDuringAGesture(kind: EventBlockPolicy.Kind) {
        #expect(EventBlockPolicy.shouldBlock(kind: kind, activeListener: true, gestureActive: true))
    }

    @Test func passesWhenTheSettingIsOff() {
        #expect(!EventBlockPolicy.shouldBlock(kind: .scroll, activeListener: false, gestureActive: true))
    }

    @Test func passesWhenNoGestureIsActive() {
        #expect(!EventBlockPolicy.shouldBlock(kind: .scroll, activeListener: true, gestureActive: false))
    }

    @Test func neverBlocksOtherEvents() {
        #expect(!EventBlockPolicy.shouldBlock(kind: .other, activeListener: true, gestureActive: true))
    }

    @Test func tapIsActiveOnlyWithTheSetting() {
        var s = SweepSettings()
        #expect(!EventBlockPolicy.needsActiveTap(settings: s))
        s.activeEventListener = true
        #expect(EventBlockPolicy.needsActiveTap(settings: s))
    }
}
