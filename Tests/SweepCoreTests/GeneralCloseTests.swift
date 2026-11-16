import Testing
@testable import SweepCore

/// The general modifier + swipe down closes the window.
@Suite struct GeneralCloseTests {
    @Test func generalSwipeDownClosesOnLift() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)], roles: [.general]) == .close)
    }

    @Test func notLive() {
        #expect(TitlebarActions.action(for: [.swipe(.down)], roles: [.general]) == nil)
        #expect(TitlebarActions.action(for: [.swipe(.down), .pause, .swipe(.down)], roles: [.general]) == nil)
    }

    @Test func doubleSwipeDownWithGeneralDoesNothing() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.down), .pause, .swipe(.down)], roles: [.general]) == nil)
    }

    @Test func otherRulesStay() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)], roles: []) == .minimize)
        #expect(TitlebarActions.finalAction(for: [.tap], roles: [.general]) == .hideApp)
        #expect(TitlebarActions.finalAction(for: [.pinchIn], roles: []) == .close)
    }

    @Test func helpRowMatchesTheMapper() {
        let row = GestureHelp.titlebar.first { $0.role == .general && $0.steps == [.swipe(.down)] }
        #expect(row != nil)
        if let row {
            #expect(TitlebarActions.finalAction(for: row.steps, roles: [.general]) == .close)
        }
    }
}
