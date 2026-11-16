import Testing
@testable import SweepCore

@Suite struct MenuBarPolicyTests {
    @Test func iconFollowsTheSetting() {
        var s = SweepSettings()
        #expect(MenuBarPolicy.iconVisible(settings: s))
        s.showInMenuBar = false
        #expect(!MenuBarPolicy.iconVisible(settings: s))
    }

    @Test func reopeningAlwaysOpensSettings() {
        // With the icon hidden this is the only way back in, so it must never be off.
        #expect(MenuBarPolicy.openSettingsOnReopen(iconVisible: false))
        #expect(MenuBarPolicy.openSettingsOnReopen(iconVisible: true))
    }

    @Test func noProblemRowWhenAllIsWell() {
        #expect(MenuBarPolicy.problem(permission: .granted, inputFailed: false) == nil)
    }

    @Test func noProblemRowWhileStillChecking() {
        // At launch the status is unknown for a moment; do not flash a warning.
        #expect(MenuBarPolicy.problem(permission: .unknown, inputFailed: false) == nil)
    }

    @Test func missingPermissionAsksForAccess() {
        let p = MenuBarPolicy.problem(permission: .denied, inputFailed: false)
        #expect(p?.fix == .grantAccess)
        #expect(p?.message == "Sweep needs Accessibility access")
        #expect(p?.fixTitle == "Grant Access…")
    }

    @Test func missingPermissionWinsOverInputFailure() {
        // Input cannot start without trust, so the permission fix comes first.
        #expect(MenuBarPolicy.problem(permission: .denied, inputFailed: true)?.fix == .grantAccess)
    }

    @Test func inputFailureOffersRetry() {
        let p = MenuBarPolicy.problem(permission: .granted, inputFailed: true)
        #expect(p?.fix == .retryInput)
        #expect(p?.message == "Gestures could not start")
        #expect(p?.fixTitle == "Try Again")
    }
}
