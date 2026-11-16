import Foundation
import Testing
@testable import SweepCore

/// A welcome tutorial on first launch, and again from About.
@Suite struct TutorialTests {
    @Test func pagesInOrder() {
        #expect(Tutorial.pages.map(\.title) == ["Windows, in one motion", "Let Sweep move your windows", "Swipe on a titlebar to snap",
                                                "Pinch, swipe, done", "The Dock and the menu bar",
                                                "Hold a key for more"])
        #expect(Tutorial.pages.allSatisfy { !$0.body.isEmpty })
    }

    @Test func everyPageHasArt() {
        #expect(Tutorial.pages.map(\.art) == ["welcome-hero", "gesture-permission", "gesture-snap", "gesture-close",
                                              "gesture-dock-menubar", "gesture-modifiers"])
    }

    @Test func gestureRowsComeFromTheHelpLists() {
        let rows = Tutorial.pages.flatMap(\.rows)
        let known = GestureHelp.titlebar + GestureHelp.menubar
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { known.contains($0) })
    }

    /// The Accessibility ask is part of the Welcome window, right after the first page.
    @Test func permissionPageIsSecond() {
        #expect(Tutorial.pages.map(\.kind).filter { $0 == .permission }.count == 1)
        #expect(Tutorial.pages[1].kind == .permission)
        #expect(Tutorial.pages.enumerated().allSatisfy { $0.offset == 1 || $0.element.kind == .info })
    }

    @Test func nextLabelOffersSkipOnlyWhilePermissionIsMissing() {
        #expect(Tutorial.nextLabel(at: 1, granted: false) == "Skip for Now")
        #expect(Tutorial.nextLabel(at: 1, granted: true) == "Next")
        #expect(Tutorial.nextLabel(at: 0, granted: false) == "Next")
        #expect(Tutorial.nextLabel(at: Tutorial.pages.count - 1, granted: false) == "Start Sweeping")
    }

    @Test func firstPageNoLongerCarriesThePermissionText() {
        #expect(!Tutorial.pages[0].body.contains("Accessibility"))
    }

    @Test func showsUntilSeen() {
        var s = SweepSettings()
        #expect(Tutorial.shouldShowOnLaunch(settings: s))
        s.tutorialSeen = true
        #expect(!Tutorial.shouldShowOnLaunch(settings: s))
    }

    @Test func restoreAllKeepsTutorialSeen() {
        var s = SweepSettings()
        s.tutorialSeen = true
        #expect(s.restoredDefaults().tutorialSeen)
    }

    @Test func oldSettingsDecodeAsNotSeen() throws {
        let s = try JSONDecoder().decode(SweepSettings.self, from: Data(#"{"sensitivity": 2}"#.utf8))
        #expect(!s.tutorialSeen)
    }

    @Test func pageNavigationStaysInRange() {
        #expect(Tutorial.next(after: 0) == 1)
        #expect(Tutorial.next(after: Tutorial.pages.count - 1) == nil)
        #expect(Tutorial.previous(before: 0) == nil)
        #expect(Tutorial.previous(before: 2) == 1)
    }
}
