import Testing
@testable import SweepCore

/// On the menu bar, tap and hold opens the app switcher; swipes move through it; lifting picks the app.
@Suite struct MenubarSwitcherTests {
    @Test func holdFirstOpens() {
        #expect(MenubarSwitcher.live(newStep: .hold, steps: [.hold]) == .open)
    }

    @Test func swipesAfterTheHoldStep() {
        #expect(MenubarSwitcher.live(newStep: .swipe(.right), steps: [.hold, .swipe(.right)]) == .step(forward: true))
        #expect(MenubarSwitcher.live(newStep: .swipe(.left), steps: [.hold, .swipe(.right), .pause, .swipe(.left)])
                == .step(forward: false))
    }

    @Test func nothingWithoutALeadingHold() {
        #expect(MenubarSwitcher.live(newStep: .swipe(.right), steps: [.swipe(.right)]) == nil)
        #expect(MenubarSwitcher.live(newStep: .hold, steps: [.swipe(.left), .hold]) == nil)
        #expect(MenubarSwitcher.live(newStep: .swipe(.up), steps: [.hold, .swipe(.up)]) == nil)
    }

    @Test func liftPicksAndCancelDismisses() {
        #expect(MenubarSwitcher.end(steps: [.hold, .swipe(.right)]) == .close)
        #expect(MenubarSwitcher.end(steps: [.swipe(.right)]) == nil)
        #expect(MenubarSwitcher.cancel(steps: [.hold]) == .dismiss)
        #expect(MenubarSwitcher.cancel(steps: [.tap]) == nil)
    }

    @Test func plainMenubarRulesSkipHoldGestures() {
        #expect(MenubarActions.finalAction(for: [.hold, .swipe(.right)], roles: []) == nil)
        #expect(MenubarActions.finalAction(for: [.swipe(.right)], roles: []) == .switchApp(forward: true))
    }
}
