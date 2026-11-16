import Testing
@testable import SweepCore

/// Magic Mouse swipes and double taps work while a modifier is held.
@Suite struct MouseGestureTests {
    @Test func noRecentTrackpadTouchesMeansMouse() {
        var f = MouseFilter()
        #expect(f.isMouse(time: 5))
        f.noteTouches(count: 2, time: 10)
        #expect(!f.isMouse(time: 10.1))
        #expect(f.isMouse(time: 10.25))
    }

    @Test func singleTouchesDoNotCountAsTrackpad() {
        var f = MouseFilter()
        f.noteTouches(count: 1, time: 10)
        #expect(f.isMouse(time: 10.05))
    }

    @Test func trackpadAlwaysPasses() {
        #expect(MouseGesturePolicy.allows(fromMouse: false, roles: [], settings: SweepSettings()))
    }

    @Test func mouseNeedsAModifier() {
        let s = SweepSettings()
        #expect(!MouseGesturePolicy.allows(fromMouse: true, roles: [], settings: s))
        #expect(MouseGesturePolicy.allows(fromMouse: true, roles: [.general], settings: s))
        #expect(MouseGesturePolicy.allows(fromMouse: true, roles: [.superKey], settings: s))
    }

    @Test func disableMagicMouseBlocksIt() {
        var s = SweepSettings()
        s.disableMagicMouse = true
        #expect(!MouseGesturePolicy.allows(fromMouse: true, roles: [.general], settings: s))
    }
}

@Suite struct InputEventTimeTests {
    @Test func everyCaseHasItsTime() {
        #expect(InputEvent.scroll(dx: 1, dy: 0, phase: .began, time: 2).time == 2)
        #expect(InputEvent.magnify(0.1, phase: .changed, time: 3).time == 3)
        #expect(InputEvent.smartMagnify(time: 4).time == 4)
    }
}
