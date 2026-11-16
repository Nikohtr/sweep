import Testing
@testable import SweepCore

@Suite struct UpdatePolicyTests {
    @Test func enabledWithKeyAndFeed() {
        #expect(UpdatePolicy.isEnabled(publicKey: "abc=", feedURL: "https://x/appcast.xml"))
    }

    @Test func offWithoutKey() {
        // Contributor builds and `swift run` have no update key: updates stay off, the app still runs.
        #expect(!UpdatePolicy.isEnabled(publicKey: nil, feedURL: "https://x/appcast.xml"))
        #expect(!UpdatePolicy.isEnabled(publicKey: "  ", feedURL: "https://x/appcast.xml"))
    }

    @Test func offWithoutFeed() {
        #expect(!UpdatePolicy.isEnabled(publicKey: "abc=", feedURL: nil))
        #expect(!UpdatePolicy.isEnabled(publicKey: "abc=", feedURL: ""))
    }

    @Test func menuTitleOnlyWhenAnUpdateWaits() {
        #expect(UpdatePolicy.menuTitle(pendingVersion: nil) == nil)
        #expect(UpdatePolicy.menuTitle(pendingVersion: "1.1.0") == "Update Available: 1.1.0…")
    }

    @Test func gentleReminderOnlyWithAVisibleIcon() {
        // With the icon hidden nobody would see the badge, so Sparkle shows its window.
        #expect(UpdatePolicy.useGentleReminder(iconVisible: true))
        #expect(!UpdatePolicy.useGentleReminder(iconVisible: false))
    }
}
