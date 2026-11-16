import Testing
@testable import SweepCore

/// With the super modifier, a gesture on a Dock icon is a window gesture on that app's
/// front window.
@Suite struct SuperDockTests {
    @Test func superPassesTheStepsThrough() {
        #expect(DockActions.superWindowSteps([.swipe(.left)], roles: [.superKey]) == [.swipe(.left)])
        #expect(DockActions.superWindowSteps([.pinchIn], roles: [.superKey, .secondary]) == [.pinchIn])
    }

    @Test func withoutSuperItIsADockGesture() {
        #expect(DockActions.superWindowSteps([.swipe(.left)], roles: []) == nil)
        #expect(DockActions.superWindowSteps([.swipe(.left)], roles: [.general]) == nil)
    }

    @Test func dockActionsStayQuietWithSuper() {
        #expect(DockActions.finalAction(for: [.pinchIn], roles: [.superKey]) == nil)
        #expect(DockActions.liveAction(newStep: .swipe(.right), steps: [.swipe(.right)], roles: [.superKey]) == nil)
        #expect(DockActions.liveAction(newStep: .hold, steps: [.hold], roles: [.superKey]) == nil)
    }

    @Test func dockActionsUnchangedWithoutSuper() {
        #expect(DockActions.finalAction(for: [.pinchIn], roles: []) == .quit)
        #expect(DockActions.liveAction(newStep: .swipe(.right), steps: [.swipe(.right)], roles: []) == .cycleWindows(forward: true))
    }
}
