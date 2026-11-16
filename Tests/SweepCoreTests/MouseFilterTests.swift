import Testing
@testable import SweepCore

// Mouse filter rule.
@Suite struct MouseFilterTests {
    @Test func offAcceptsEverything() {
        let f = MouseFilter()
        #expect(f.accepts(time: 10, disableMouse: false))
    }

    @Test func onNeedsRecentTrackpadTouches() {
        var f = MouseFilter()
        #expect(!f.accepts(time: 1, disableMouse: true))     // no trackpad touch seen yet
        f.noteTouches(count: 2, time: 1)
        #expect(f.accepts(time: 1.125, disableMouse: true))
        #expect(!f.accepts(time: 1.25, disableMouse: true))  // 0.2 s or more after: dropped
        // (exact binary times; 1.2 − 1 is slightly below 0.2 in floating point)
    }

    @Test func oneFingerDoesNotCount() {
        var f = MouseFilter()
        f.noteTouches(count: 1, time: 1)
        #expect(!f.accepts(time: 1.05, disableMouse: true))
    }

    @Test func settingExists() {
        #expect(!SweepSettings().disableMagicMouse)
    }
}
