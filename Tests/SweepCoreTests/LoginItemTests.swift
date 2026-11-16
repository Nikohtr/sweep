import Testing
@testable import SweepCore

@Suite struct LoginItemTests {
    @Test(arguments: [
        (true, LoginItemStatus.notRegistered, LoginItemPlan.Action.register),
        (true, .enabled, .none),
        (true, .requiresApproval, .none),
        (false, .enabled, .unregister),
        (false, .requiresApproval, .unregister),
        (false, .notRegistered, .none),
        (true, .notFound, .register),
    ])
    func actionFromWishAndStatus(wanted: Bool, current: LoginItemStatus, expected: LoginItemPlan.Action) {
        #expect(LoginItemPlan.action(wanted: wanted, current: current) == expected)
    }

    @Test func toggleShowsOnOnlyWhenEnabledOrPending() {
        #expect(LoginItemPlan.isOn(.enabled))
        #expect(LoginItemPlan.isOn(.requiresApproval))
        #expect(!LoginItemPlan.isOn(.notRegistered))
        #expect(!LoginItemPlan.isOn(.notFound))
    }

    @Test func approvalNeedsAMessage() {
        #expect(LoginItemPlan.message(for: .requiresApproval) != nil)
        #expect(LoginItemPlan.message(for: .enabled) == nil)
    }
}
