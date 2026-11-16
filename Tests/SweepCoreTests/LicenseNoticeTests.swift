import Testing
@testable import SweepCore

@Suite struct LicenseNoticeTests {
    @Test func sweepIsGPL3() {
        let sweep = LicenseNotice.sweep
        #expect(sweep.component == "Sweep")
        #expect(sweep.license == "GPL-3.0")
        #expect(sweep.resourceFile == "LICENSE.txt")
    }

    @Test func sparkleIsMIT() {
        let sparkle = LicenseNotice.sparkle
        #expect(sparkle.component == "Sparkle")
        #expect(sparkle.license == "MIT")
        #expect(sparkle.resourceFile == "Sparkle-LICENSE.txt")
    }

    @Test func allListsSweepFirstThenEveryDependency() {
        #expect(LicenseNotice.all.map(\.component) == ["Sweep", "Sparkle"])
        // Each notice ships as its own file in Contents/Resources (scripts/bundle.sh copies them).
        #expect(Set(LicenseNotice.all.map(\.resourceFile)).count == LicenseNotice.all.count)
    }

    @Test func aboutLineNamesEveryLicense() {
        #expect(LicenseNotice.aboutLine
            == "Sweep is free software under the GPL-3.0 license. It uses Sparkle (MIT license).")
    }
}
