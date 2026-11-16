import Testing
@testable import SweepCore

/// With two screens, screen modifier + pinch out, or pinch out twice, puts the window
/// in fullscreen on the other screen.
@Suite struct OtherScreenFullscreenTests {
    @Test func screenModifierPinchOut() {
        #expect(TitlebarActions.finalAction(for: [.pinchOut], roles: [.screen]) == .fullscreenOnOtherScreen)
    }

    @Test func pinchOutTwiceWithoutModifiers() {
        #expect(TitlebarActions.finalAction(for: [.pinchOut, .pause, .pinchOut]) == .fullscreenOnOtherScreen)
        #expect(TitlebarActions.finalAction(for: [.pinchOut, .pinchOut], roles: []) == .fullscreenOnOtherScreen)
    }

    @Test func onlyOnLift() {
        #expect(TitlebarActions.action(for: [.pinchOut], roles: [.screen]) == nil)
        #expect(TitlebarActions.action(for: [.pinchOut, .pause, .pinchOut]) == nil)
    }

    @Test func singlePinchOutStillTogglesFullscreen() {
        #expect(TitlebarActions.finalAction(for: [.pinchOut]) == .toggleFullscreen)
    }

    @Test func screenModifierSwipeStillMoves() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.right)], roles: [.screen]) == .moveToScreen(.right))
    }

    @Test func otherScreenIsTheNextIndex() {
        #expect(ScreenLayout.otherScreen(of: 0, count: 2) == 1)
        #expect(ScreenLayout.otherScreen(of: 1, count: 2) == 0)
        #expect(ScreenLayout.otherScreen(of: 2, count: 3) == 0)
    }

    @Test func noOtherScreenWithOneScreen() {
        #expect(ScreenLayout.otherScreen(of: 0, count: 1) == nil)
        #expect(ScreenLayout.otherScreen(of: 3, count: 2) == nil)
    }

    @Test func planMovesWaitsThenFullscreens() {
        #expect(ActionPlan.steps(for: .fullscreenOnOtherScreen, isFullscreen: false) == [
            .perform(.moveToOtherScreen), .wait(ActionPlan.screenMoveDelay), .perform(.toggleFullscreen),
        ])
        #expect(ActionPlan.screenMoveDelay == 0.3)
    }

    @Test func planLeavesFullscreenFirst() {
        #expect(ActionPlan.steps(for: .fullscreenOnOtherScreen, isFullscreen: true) == [
            .perform(.toggleFullscreen), .wait(ActionPlan.fullscreenExitDelay),
            .perform(.moveToOtherScreen), .wait(ActionPlan.screenMoveDelay), .perform(.toggleFullscreen),
        ])
    }

    @Test func planWithOneScreenOnlyToggles() {
        #expect(ActionPlan.steps(for: .fullscreenOnOtherScreen, isFullscreen: false, hasOtherScreen: false)
                == [.perform(.toggleFullscreen)])
    }
}
