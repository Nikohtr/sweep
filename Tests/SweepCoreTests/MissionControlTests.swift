import CoreGraphics
import Testing
@testable import SweepCore

/// Window gestures in Mission Control and App Exposé.
@Suite struct MissionControlTests {
    @Test func showingWhenTheDockHasTheModeElement() {
        #expect(MissionControlState.isShowing(dockChildTitles: [nil, "Mission Control"]))
        #expect(MissionControlState.isShowing(dockChildTitles: ["App Expose"]))
        #expect(!MissionControlState.isShowing(dockChildTitles: ["Dock", nil]))
        #expect(!MissionControlState.isShowing(dockChildTitles: []))
    }

    @Test func exactTitleWins() {
        #expect(WindowMatch.best(title: "Notes", candidates: ["Notes — draft", "Notes", "Mail"]) == 1)
    }

    @Test func uniquePrefixMatches() {
        #expect(WindowMatch.best(title: "Report", candidates: ["Report.pdf", "Mail"]) == 0)
    }

    @Test func ambiguousOrMissingGivesNil() {
        #expect(WindowMatch.best(title: "Untitled", candidates: ["Untitled", "Untitled"]) == nil)
        #expect(WindowMatch.best(title: "Doc", candidates: ["Doc 1", "Doc 2"]) == nil)
        #expect(WindowMatch.best(title: "", candidates: ["A"]) == nil)
        #expect(WindowMatch.best(title: "Zed", candidates: ["A"]) == nil)
    }

    private func hit(inMC: Bool) -> HitInfo {
        HitInfo(cursor: CGPoint(x: 300, y: 300), role: "AXButton", windowFrame: nil, isFullscreen: false,
                screenVisibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), inMissionControl: inMC)
    }

    @Test func originInMissionControl() {
        #expect(OriginClassifier.classify(hit(inMC: true)) == .missionControl)
        #expect(OriginClassifier.classify(hit(inMC: false)) == nil)
    }

    @Test func settingTurnsItOff() {
        var s = SweepSettings()
        #expect(GestureGate.origin(hit: hit(inMC: true), held: [], settings: s) == .missionControl)
        s.missionControlGestures = false
        #expect(GestureGate.origin(hit: hit(inMC: true), held: [], settings: s) == nil)
    }

    @Test func actionsOnLift() {
        #expect(MissionControlActions.finalAction(for: [.pinchIn]) == .close)
        #expect(MissionControlActions.finalAction(for: [.swipe(.down)]) == .minimize)
        #expect(MissionControlActions.finalAction(for: [.swipe(.left)]) == .snap(.leftHalf))
        #expect(MissionControlActions.finalAction(for: [.swipe(.right)]) == .snap(.rightHalf))
        #expect(MissionControlActions.finalAction(for: [.pause, .swipe(.up)]) == .snap(.maximize))
        #expect(MissionControlActions.finalAction(for: [.swipe(.left), .swipe(.up)]) == nil)
        #expect(MissionControlActions.leaveDelay == 0.3)
    }
}
