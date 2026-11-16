import Testing
@testable import SweepCore

@Suite struct AppVersionTests {
    @Test func showsVersionAndBuild() {
        #expect(AppVersion.display(short: "1.0.0", build: "212") == "Version 1.0.0 (212)")
    }

    @Test func trimsWhitespace() {
        // VERSION ends with a newline; the plist value must not carry it into the UI.
        #expect(AppVersion.display(short: "1.0.0\n", build: " 212 ") == "Version 1.0.0 (212)")
    }

    @Test func noBundleMeansDevBuild() {
        // `swift run` has no Info.plist values.
        #expect(AppVersion.display(short: nil, build: nil) == "Development build")
        #expect(AppVersion.display(short: "", build: "3") == "Development build")
    }

    @Test func versionWithoutBuild() {
        #expect(AppVersion.display(short: "1.0.0", build: nil) == "Version 1.0.0")
    }
}
