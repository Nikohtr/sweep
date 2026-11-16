import Testing
@testable import SweepCore

@Suite struct MoveToApplicationsTests {
    let home = "/Users/alex"
    typealias M = MoveToApplications

    func place(_ path: String, packageNearby: Bool = false) -> M.Location {
        M.classify(bundlePath: path, homeDirectory: home, packageManifestNearby: packageNearby)
    }

    @Test func applicationsFoldersNeedNoMove() {
        #expect(place("/Applications/Sweep.app") == .applications)
        #expect(place("/Applications/Utilities/Sweep.app") == .applications)
        #expect(place("/Users/alex/Applications/Sweep.app") == .applications)
        // Trailing slash and "." parts do not change the answer.
        #expect(place("/Applications/./Sweep.app/") == .applications)
    }

    @Test func lookalikeFoldersAreNotApplications() {
        #expect(place("/ApplicationsOld/Sweep.app") == .elsewhere)
        #expect(place("/Users/alex/Downloads/Applications Backup/Sweep.app") == .elsewhere)
        #expect(place("/Users/bob/Applications/Sweep.app") == .elsewhere)
    }

    @Test func downloadsIsElsewhere() {
        #expect(place("/Users/alex/Downloads/Sweep.app") == .elsewhere)
        #expect(place("/Volumes/Sweep/Sweep.app") == .elsewhere)
    }

    @Test func appTranslocationIsDetected() {
        let path = "/private/var/folders/5d/1zskmzgj1f9c1q3hfsv9d8p00000gn/T/AppTranslocation/"
            + "8A2E66C2-1C55-4D3B-9C55-7E0B1F0F3C11/d/Sweep.app"
        #expect(place(path) == .translocated)
        #expect(place(path.replacingOccurrences(of: "/private", with: "")) == .translocated)
    }

    @Test func devBuildsAreNeverAsked() {
        // `swift run`: the executable is not inside an .app bundle.
        #expect(place("/Users/alex/code/sweep/.build/arm64-apple-macosx/debug") == .devBuild)
        // scripts/bundle.sh output: build/Sweep.app next to Package.swift.
        #expect(place("/Users/alex/code/sweep/build/Sweep.app", packageNearby: true) == .devBuild)
        // Same folder name without a package next to it is a normal copy.
        #expect(place("/Users/alex/Desktop/build/Sweep.app", packageNearby: false) == .elsewhere)
    }

    @Test func asksOnlyOutsideApplicationsAndOnlyWhenAllowed() {
        #expect(M.shouldAsk(.elsewhere, dontAskAgain: false, debugFlag: false))
        #expect(M.shouldAsk(.translocated, dontAskAgain: false, debugFlag: false))
        #expect(!M.shouldAsk(.applications, dontAskAgain: false, debugFlag: false))
        #expect(!M.shouldAsk(.devBuild, dontAskAgain: false, debugFlag: false))
        #expect(!M.shouldAsk(.elsewhere, dontAskAgain: true, debugFlag: false))
        #expect(!M.shouldAsk(.translocated, dontAskAgain: false, debugFlag: true))
    }

    @Test func destinationPrefersTheSharedApplicationsFolder() {
        #expect(M.destination(appName: "Sweep.app", homeDirectory: home, applicationsWritable: true)
            == "/Applications/Sweep.app")
        #expect(M.destination(appName: "Sweep.app", homeDirectory: home, applicationsWritable: false)
            == "/Users/alex/Applications/Sweep.app")
    }

    @Test func planForANormalCopy() {
        let steps = M.plan(source: "/Users/alex/Downloads/Sweep.app", destination: "/Applications/Sweep.app",
                           location: .elsewhere, destinationExists: false)
        #expect(steps == [.copy(from: "/Users/alex/Downloads/Sweep.app", to: "/Applications/Sweep.app"),
                          .removeQuarantine("/Applications/Sweep.app"),
                          .trash("/Users/alex/Downloads/Sweep.app"),
                          .relaunch("/Applications/Sweep.app")])
    }

    @Test func oldCopyGoesToTheTrashFirst() {
        let steps = M.plan(source: "/Users/alex/Downloads/Sweep.app", destination: "/Applications/Sweep.app",
                           location: .elsewhere, destinationExists: true)
        #expect(steps.first == .trash("/Applications/Sweep.app"))
        #expect(steps.count == 5)
    }

    @Test func translocatedCopyKeepsTheHiddenOriginal() {
        // The translocated path is a read-only view; the real file's place is unknown, so leave it.
        let src = "/private/var/folders/x/T/AppTranslocation/ID/d/Sweep.app"
        let steps = M.plan(source: src, destination: "/Applications/Sweep.app",
                           location: .translocated, destinationExists: false)
        #expect(steps == [.copy(from: src, to: "/Applications/Sweep.app"),
                          .removeQuarantine("/Applications/Sweep.app"),
                          .relaunch("/Applications/Sweep.app")])
        #expect(!steps.contains(.trash(src)))
    }

    @Test func manualStepsNameTheFolder() {
        #expect(M.manualSteps(location: .elsewhere, sourceFolder: "Downloads")
            == "Quit Sweep. In Finder, drag Sweep from Downloads to Applications. Then open it from Applications.")
        #expect(M.manualSteps(location: .translocated, sourceFolder: "d")
            == "Quit Sweep. In Finder, drag Sweep from the folder you downloaded it to (for example Downloads) "
            + "to Applications. Then open it from Applications.")
    }
}
