import Testing
@testable import SweepCore

@Suite struct DockActionTests {
    @Test func pinchInQuitsOnLift() {
        #expect(DockActions.finalAction(for: [.pinchIn], roles: []) == .quit)
        #expect(DockActions.finalAction(for: [.pinchIn, .pause], roles: []) == .quit)
    }

    @Test func quitIsNeverLive() {
        #expect(DockActions.action(for: [.pinchIn], roles: []) == nil)
    }

    @Test func otherStepsDoNotQuit() {
        #expect(DockActions.finalAction(for: [.pinchIn, .pinchOut], roles: []) != .quit)
        #expect(DockActions.finalAction(for: [.swipe(.left), .pinchIn], roles: []) != .quit)
        #expect(DockActions.finalAction(for: [], roles: []) == nil)
    }
}

@Suite struct DockHideTests {
    @Test func doubleTapHides() {
        #expect(DockActions.finalAction(for: [.tap], roles: []) == .hide)
    }

    @Test func secondaryHidesOthers() {
        #expect(DockActions.finalAction(for: [.tap], roles: [.secondary]) == .hideOthers)
    }

    @Test func pinchStillQuitsWithSecondary() {
        #expect(DockActions.finalAction(for: [.pinchIn], roles: [.secondary]) == .quit)
    }

    @Test func twoTapsAreNotHide() {
        #expect(DockActions.finalAction(for: [.tap, .tap], roles: []) == nil)
    }

    @Test func othersToHideSkipsTargetAndSelf() {
        let all = [AppRef(id: "a", regular: true), AppRef(id: "b", regular: true),
                   AppRef(id: "me", regular: true), AppRef(id: "agent", regular: false)]
        #expect(DockActions.othersToHide(target: "a", running: all, selfID: "me") == ["b"])
    }
}

@Suite struct DockMinimizeTests {
    @Test func swipeDownAndUp() {
        #expect(DockActions.finalAction(for: [.swipe(.down)], roles: []) == .minimizeFront)
        #expect(DockActions.finalAction(for: [.swipe(.up)], roles: []) == .unminimizeLast)
        #expect(DockActions.finalAction(for: [.swipe(.down)], roles: [.secondary]) == .minimizeAll)
        #expect(DockActions.finalAction(for: [.swipe(.up)], roles: [.secondary]) == .unminimizeAll)
    }

    @Test func sidewaysIsNotMinimize() {
        #expect(DockActions.finalAction(for: [.swipe(.left)], roles: []) == nil)
    }

    @Test func minimizePicksFocusedThenFirstVisible() {
        #expect(WindowPick.minimizeTargets(minimized: [false, false], focused: 1, all: false) == [1])
        #expect(WindowPick.minimizeTargets(minimized: [true, false], focused: 0, all: false) == [1])
        #expect(WindowPick.minimizeTargets(minimized: [false, true, false], focused: nil, all: true) == [0, 2])
        #expect(WindowPick.minimizeTargets(minimized: [true], focused: nil, all: false).isEmpty)
    }

    @Test func unminimizePicksLastMinimized() {
        #expect(WindowPick.unminimizeTargets(minimized: [true, false, true], all: false) == [2])
        #expect(WindowPick.unminimizeTargets(minimized: [true, false, true], all: true) == [0, 2])
        #expect(WindowPick.unminimizeTargets(minimized: [false], all: false).isEmpty)
    }
}

@Suite struct DockCycleTests {
    @Test func eachHorizontalSwipeStepCyclesOnce() {
        #expect(DockActions.liveAction(newStep: .swipe(.right), steps: [.swipe(.right)], roles: [])
                == .cycleWindows(forward: true))
        #expect(DockActions.liveAction(newStep: .swipe(.left), steps: [.swipe(.right), .swipe(.left)], roles: [])
                == .cycleWindows(forward: false))
    }

    @Test func pauseAndOtherStepsDoNotCycle() {
        #expect(DockActions.liveAction(newStep: .pause, steps: [.swipe(.right), .pause], roles: []) == nil)
        #expect(DockActions.liveAction(newStep: .swipe(.down), steps: [.swipe(.down)], roles: []) == nil)
        #expect(DockActions.liveAction(newStep: .swipe(.right), steps: [.swipe(.down), .swipe(.right)], roles: []) == nil)
    }

    @Test func cyclingIsNotRepeatedOnLift() {
        #expect(DockActions.finalAction(for: [.swipe(.right)], roles: []) == nil)
    }

    @Test func forwardRaisesTheBackmostVisibleWindow() {
        // Front-to-back order; the last visible window comes to the front, so repeats visit every window.
        #expect(WindowPick.cycleTarget(minimized: [false, false, false], forward: true) == 2)
        #expect(WindowPick.cycleTarget(minimized: [false, false, true], forward: true) == 1)
    }

    @Test func backwardRaisesTheOneBehindTheFront() {
        #expect(WindowPick.cycleTarget(minimized: [false, true, false], forward: false) == 2)
    }

    @Test func oneWindowNothingToCycle() {
        #expect(WindowPick.cycleTarget(minimized: [false], forward: true) == nil)
        #expect(WindowPick.cycleTarget(minimized: [false, true], forward: false) == nil)
    }
}

@Suite struct DockChainTests {
    @Test func holdActivatesTheApp() {
        #expect(DockActions.liveAction(newStep: .hold, steps: [.hold], roles: []) == .activate)
    }

    @Test func stepsAfterHoldAreChained() {
        #expect(DockActions.chainedSteps([.hold, .swipe(.left)]) == [.swipe(.left)])
        #expect(DockActions.chainedSteps([.hold]) == [])
        #expect(DockActions.chainedSteps([.swipe(.left)]) == nil)
    }

    @Test func chainedStepsAreTitlebarGestures() {
        let chained = DockActions.chainedSteps([.hold, .swipe(.left), .swipe(.up)])!
        #expect(TitlebarActions.action(for: chained) == .snap(.topLeft))
    }

    @Test func chainDisablesDockOnlyRules() {
        // Inside a chain, swipes must not also cycle windows or minimize the app.
        #expect(DockActions.liveAction(newStep: .swipe(.right), steps: [.hold, .swipe(.right)], roles: []) == nil)
        #expect(DockActions.finalAction(for: [.hold, .swipe(.down)], roles: []) == nil)
    }
}
