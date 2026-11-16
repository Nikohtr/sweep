import Testing
@testable import SweepCore

@Suite struct PermissionFlowTests {
    @Test func trustedAtLaunchStartsInput() {
        var f = PermissionFlow()
        #expect(f.update(trusted: true) == [.startInput, .recheck(after: PermissionFlow.grantedRecheck)])
        #expect(f.status == .granted)
    }

    @Test func untrustedAtLaunchPromptsOnceAndPolls() {
        var f = PermissionFlow()
        #expect(f.update(trusted: false) == [.promptSystem, .recheck(after: PermissionFlow.deniedRecheck)])
        #expect(f.status == .denied)
        #expect(f.update(trusted: false) == [.recheck(after: PermissionFlow.deniedRecheck)])
    }

    @Test func grantWhileRunningStartsInput() {
        var f = PermissionFlow()
        _ = f.update(trusted: false)
        #expect(f.update(trusted: true) == [.startInput, .recheck(after: PermissionFlow.grantedRecheck)])
    }

    @Test func grantedStaysQuiet() {
        var f = PermissionFlow()
        _ = f.update(trusted: true)
        #expect(f.update(trusted: true) == [.recheck(after: PermissionFlow.grantedRecheck)])
    }

    @Test func revokeStopsInputWithoutNewPrompt() {
        var f = PermissionFlow()
        _ = f.update(trusted: true)
        #expect(f.update(trusted: false) == [.stopInput, .recheck(after: PermissionFlow.deniedRecheck)])
        #expect(f.status == .denied)
    }

    @Test func revokeBeforeAnyPromptStillPromptsOnce() {
        var f = PermissionFlow()
        _ = f.update(trusted: true)
        _ = f.update(trusted: false)
        _ = f.update(trusted: true)
        // Prompt was never shown, but a revoke is a user choice: do not nag.
        #expect(f.update(trusted: false) == [.stopInput, .recheck(after: PermissionFlow.deniedRecheck)])
    }

    @Test func userRequestOpensSettingsOnlyWhenDenied() {
        var f = PermissionFlow()
        _ = f.update(trusted: false)
        #expect(f.userRequested() == [.openSettings])
        var g = PermissionFlow()
        _ = g.update(trusted: true)
        #expect(g.userRequested().isEmpty)
    }

    @Test func pollingIsFasterWhileDenied() {
        #expect(PermissionFlow.deniedRecheck < PermissionFlow.grantedRecheck)
    }

    /// The Welcome window asks for permission itself, so launch does not show the system dialog.
    @Test func noLaunchPromptWhenTheWelcomeAsks() {
        var f = PermissionFlow(promptAtLaunch: false)
        #expect(f.update(trusted: false) == [.recheck(after: PermissionFlow.deniedRecheck)])
        #expect(!f.hasPrompted)
    }

    /// First request shows the system dialog (it also adds Sweep to the list); later ones open the page.
    @Test func firstUserRequestPromptsThenOpensSettings() {
        var f = PermissionFlow(promptAtLaunch: false)
        _ = f.update(trusted: false)
        #expect(f.userRequested() == [.promptSystem])
        #expect(f.userRequested() == [.openSettings])
    }

    @Test func userRequestBeforeFirstCheckStillPrompts() {
        var f = PermissionFlow(promptAtLaunch: false)
        #expect(f.userRequested() == [.promptSystem])
    }
}
