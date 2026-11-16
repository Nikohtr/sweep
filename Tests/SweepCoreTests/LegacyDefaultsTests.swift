import Testing
@testable import SweepCore

@Suite struct LegacyDefaultsTests {
    @Test func copiesSettingsWhenTheNewIDHasNone() {
        #expect(LegacyDefaults.keysToCopy(old: ["settings.v1"], new: []) == ["settings.v1"])
    }

    @Test func neverOverwritesNewSettings() {
        #expect(LegacyDefaults.keysToCopy(old: ["settings.v1"], new: ["settings.v1"]).isEmpty)
    }

    @Test func nothingToCopyFromAnEmptyOldDomain() {
        #expect(LegacyDefaults.keysToCopy(old: [], new: []).isEmpty)
    }

    @Test func copiesOnlySweepsOwnKeys() {
        // System keys such as window frames stay behind.
        #expect(LegacyDefaults.keysToCopy(old: ["settings.v1", "NSWindow Frame x"], new: []) == ["settings.v1"])
    }

    @Test func oldDomainIsTheFormerBundleID() {
        #expect(LegacyDefaults.oldDomain == "local.sweep.app")
    }
}
