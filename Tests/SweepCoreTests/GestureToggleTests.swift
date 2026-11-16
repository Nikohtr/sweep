import Foundation
import Testing
@testable import SweepCore

/// Every gesture family can be turned off in the settings.
@Suite struct GestureToggleTests {
    @Test(arguments: [
        (WindowAction.snap(.leftHalf), GestureKind.halves), (.snap(.topHalf), .halves),
        (.snap(.topLeft), .quarters), (.snap(.maximize), .maximize), (.snap(.almostMaximize), .maximize),
        (.snap(.leftThird), .thirds), (.snap(.rightTwoThirds), .thirds),
        (.snap(.grid(GridSpan(columns: 3, rows: 2, x: 0..<1, y: 0..<1))), .thirds),
        (.snap(.grid(GridSpan(columns: 3, rows: 3, x: 0..<1, y: 0..<1))), .ninths),
        (.close, .close), (.minimize, .minimize), (.toggleFullscreen, .fullscreen), (.center, .center),
        (.hideApp, .hideApps), (.hideOtherApps, .hideApps), (.moveToScreen(.left), .screens),
        (.fullscreenOnOtherScreen, .screens), (.moveToOtherScreen, .screens), (.moveToSpace(.right), .spaces),
    ])
    func kindOfAction(action: WindowAction, kind: GestureKind) {
        #expect(GestureKind.of(action) == kind)
    }

    @Test func allOnByDefault() {
        #expect(SweepSettings().disabledGestures.isEmpty)
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: [], settings: SweepSettings()) == .snap(.leftHalf))
    }

    @Test func disabledKindGivesNoAction() {
        var s = SweepSettings()
        s.disabledGestures = [.halves, .close]
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: [], settings: s) == nil)
        #expect(TitlebarActions.finalAction(for: [.pinchIn], roles: [], settings: s) == nil)
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)], roles: [], settings: s) == .minimize)
    }

    @Test func disablingMaximizeAlsoBlocksAlmostMaximize() {
        var s = SweepSettings()
        s.swipeUpFillsAlmost = true
        s.disabledGestures = [.maximize]
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: [], settings: s) == nil)
    }

    @Test func oldSettingsDecodeAllOn() throws {
        let s = try JSONDecoder().decode(SweepSettings.self, from: Data(#"{"sensitivity": 2}"#.utf8))
        #expect(s.disabledGestures.isEmpty)
    }

    @Test func everyKindHasATitle() {
        #expect(GestureKind.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(GestureKind.snapping.count + GestureKind.window.count == GestureKind.allCases.count)
    }
}
