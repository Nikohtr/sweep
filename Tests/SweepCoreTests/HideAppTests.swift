import Testing
@testable import SweepCore

@Suite struct HideAppTests {
    @Test func generalDoubleTapHidesTheAppOnLift() {
        #expect(TitlebarActions.finalAction(for: [.tap], roles: [.general]) == .hideApp)
        #expect(TitlebarActions.action(for: [.tap], roles: [.general]) == nil)   // not live, and not center
    }

    @Test func secondaryDoubleTapHidesOtherApps() {
        #expect(TitlebarActions.finalAction(for: [.tap], roles: [.secondary]) == .hideOtherApps)
        #expect(TitlebarActions.action(for: [.tap], roles: [.secondary]) == nil)
    }

    @Test func plainDoubleTapStillCenters() {
        #expect(TitlebarActions.action(for: [.tap], roles: []) == .center)
    }

    @Test func secondarySwipesStillGiveThirds() {
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: [.secondary]) == .snap(.leftThird))
    }
}
