import Testing
@testable import SweepCore

/// In-app Uninstall…. Only the plan is tested here; it never runs in tests.
@Suite struct UninstallTests {
    let id = "io.github.nikohtr.sweep"
    let home = "/Users/alex"
    typealias U = UninstallPlan

    @Test func fullPlanForAnInstalledCopy() {
        let steps = U.steps(bundleID: id, appPath: "/Applications/Sweep.app", location: .applications, homeDirectory: home)
        #expect(steps == [
            .unregisterLoginItem,
            .resetAccessibility(bundleID: id),
            .removeDefaults(domain: id),
            .removeDefaults(domain: LegacyDefaults.oldDomain),
            .removeFolder("/Users/alex/Library/Caches/\(id)"),
            .removeFolder("/Users/alex/Library/HTTPStorages/\(id)"),
            .trashApp("/Applications/Sweep.app"),
            .quit,
        ])
    }

    @Test func quitIsAlwaysLastAndTrashComesJustBefore() {
        let steps = U.steps(bundleID: id, appPath: "/Users/alex/Downloads/Sweep.app", location: .elsewhere,
                            homeDirectory: home)
        #expect(steps.last == .quit)
        #expect(steps[steps.count - 2] == .trashApp("/Users/alex/Downloads/Sweep.app"))
    }

    @Test func devAndTranslocatedCopiesAreNotTrashed() {
        // A dev build lives in the repo; a translocated path is a read-only view, not the real file.
        for location in [MoveToApplications.Location.devBuild, .translocated] {
            let steps = U.steps(bundleID: id, appPath: "/x/Sweep.app", location: location, homeDirectory: home)
            #expect(!steps.contains { if case .trashApp = $0 { return true } else { return false } })
            #expect(steps.last == .quit)
        }
    }

    @Test func accessibilityResetFallsBackToTheSettingsPane() {
        #expect(U.fallback(for: .resetAccessibility(bundleID: id)) == .openAccessibilitySettings)
        #expect(U.fallback(for: .unregisterLoginItem) == nil)
        #expect(U.fallback(for: .removeDefaults(domain: id)) == nil)
    }

    @Test func tccutilCommand() {
        #expect(U.tccutilArguments(bundleID: id) == ["reset", "Accessibility", id])
        #expect(U.accessibilitySettingsURL
            == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @Test func confirmAndDoneTexts() {
        #expect(U.confirmTitle == "Uninstall Sweep?")
        #expect(U.confirmText(trashesApp: true)
            == "Sweep turns off Open at login, deletes its settings, removes its Accessibility permission "
            + "and moves itself to the Trash. Then it quits. This cannot be undone.")
        #expect(U.confirmText(trashesApp: false)
            == "Sweep turns off Open at login, deletes its settings and removes its Accessibility permission. "
            + "Then it quits. Delete the app yourself. This cannot be undone.")
        #expect(U.accessibilityHint
            == "In Privacy & Security › Accessibility, select Sweep and click the minus button (−).")
    }
}
