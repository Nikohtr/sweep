import Testing
@testable import SweepCore

@Suite struct AXTimeoutTests {
    @Test func hitTestTimeoutIsShort() {
        // A hit test runs while the user's fingers are on the trackpad: it must give up fast.
        #expect(AXTimeouts.hitTest >= 0.1 && AXTimeouts.hitTest <= 0.25)
    }

    @Test func windowActionTimeoutIsLongerButFarBelowTheSystemDefault() {
        // macOS waits about 6 s by default. A window action may take longer than a hit test,
        // but a hung app must not freeze input for seconds.
        #expect(AXTimeouts.windowAction > AXTimeouts.hitTest)
        #expect(AXTimeouts.windowAction <= 1.0)
    }

    @Test func freshGuardAllowsCallsAndGivesContext() {
        let g = HitTestGuard()
        #expect(g.mayCall)
        #expect(g.givesContext)
    }

    @Test func plainFailuresDoNotStopTheHitTest() {
        // A missing attribute is normal (many elements have no title); keep reading.
        var g = HitTestGuard()
        g.record(.success)
        g.record(.failed)
        #expect(g.mayCall)
        #expect(g.givesContext)
    }

    @Test func aTimeoutStopsAllFurtherCallsAndDropsTheGesture() {
        var g = HitTestGuard()
        g.record(.success)
        g.record(.timedOut)
        #expect(!g.mayCall)
        #expect(!g.givesContext)
        // Later results cannot undo it.
        g.record(.success)
        #expect(!g.mayCall)
        #expect(!g.givesContext)
    }

    @Test func contextIsDroppedAfterATimeout() {
        var g = HitTestGuard()
        #expect(g.context("titlebar") == "titlebar")
        g.record(.timedOut)
        #expect(g.context("titlebar") == nil)
    }
}
