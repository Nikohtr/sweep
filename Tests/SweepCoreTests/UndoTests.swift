import CoreGraphics
import Foundation
import Testing
@testable import SweepCore

/// Undo the last window move, resize or snap.
@Suite struct UndoTests {
    let a = CGRect(x: 0, y: 0, width: 800, height: 600)
    let b = CGRect(x: 100, y: 50, width: 640, height: 480)

    @Test func popsInReverseOrder() {
        var s = UndoStack<String>()
        s.record("w1", frame: a, group: 1)
        s.record("w2", frame: b, group: 2)
        #expect(s.popAlive { _ in true }?.key == "w2")
        #expect(s.popAlive { _ in true }?.key == "w1")
        #expect(s.popAlive { _ in true } == nil)
        #expect(s.isEmpty)
    }

    @Test func oneGestureIsOneStepPerWindow() {
        // Live snaps during one gesture: undo must go back to the frame from before the gesture.
        var s = UndoStack<String>()
        s.record("w1", frame: a, group: 7)
        s.record("w1", frame: b, group: 7)
        let top = s.popAlive { _ in true }
        #expect(top?.frame == a)
        #expect(s.isEmpty)
    }

    @Test func oneGestureOnManyWindowsKeepsEach() {
        // A menu bar unsnap moves several windows in one gesture.
        var s = UndoStack<String>()
        s.record("w1", frame: a, group: 3)
        s.record("w2", frame: b, group: 3)
        s.record("w1", frame: b, group: 3)
        #expect(s.count == 2)
    }

    @Test func depthIsLimited() {
        var s = UndoStack<String>()
        for i in 0..<15 { s.record("w\(i)", frame: a, group: i) }
        #expect(s.count == UndoStack<String>.capacity)
        #expect(UndoStack<String>.capacity == 10)
        // The oldest five are gone; the newest is on top.
        #expect(s.popAlive { _ in true }?.key == "w14")
    }

    @Test func closedWindowsAreSkipped() {
        var s = UndoStack<String>()
        s.record("open", frame: a, group: 1)
        s.record("closed", frame: b, group: 2)
        let top = s.popAlive { $0 != "closed" }
        #expect(top?.key == "open")
        #expect(s.isEmpty)
    }

    @Test(arguments: [
        (WindowAction.snap(.leftHalf), true), (.snap(.maximize), true), (.center, true),
        (.moveToScreen(.left), true), (.moveToOtherScreen, true),
        (.close, false), (.minimize, false), (.toggleFullscreen, false), (.hideApp, false), (.hideOtherApps, false),
        (.moveToSpace(.right), false), (.fullscreenOnOtherScreen, false),
    ])
    func recordsOnlyMovesResizesAndSnaps(action: WindowAction, records: Bool) {
        #expect(UndoPolicy.records(action) == records)
    }

    @Test func hotkeyIsOffByDefaultAndUsesZ() {
        #expect(!SweepSettings().undoHotkey)
        #expect(HotkeyMap.undoKeyCode == 6)
    }

    @Test func activeKeyCodesFollowTheSettings() {
        var s = SweepSettings()
        #expect(HotkeyMap.activeKeyCodes(settings: s).isEmpty)
        s.undoHotkey = true
        #expect(HotkeyMap.activeKeyCodes(settings: s) == [6])
        s.arrowHotkeys = true
        let codes = HotkeyMap.activeKeyCodes(settings: s)
        #expect(codes.contains(6) && codes.contains(123) && codes.contains(53))
        s.undoHotkey = false
        #expect(!HotkeyMap.activeKeyCodes(settings: s).contains(6))
        // The undo key never clashes with a direction or center key.
        for keys in SweepSettings.ArrowKeys.allCases {
            s.arrowKeys = keys
            for center in SweepSettings.CenterKey.allCases {
                s.centerKey = center
                #expect(!HotkeyMap.registeredKeyCodes(settings: s).contains(HotkeyMap.undoKeyCode))
            }
        }
    }

    @Test func oldSettingsDecodeWithTheHotkeyOff() throws {
        let s = try JSONDecoder().decode(SweepSettings.self, from: Data(#"{"arrowHotkeys":true}"#.utf8))
        #expect(!s.undoHotkey)
        #expect(s.arrowHotkeys)
    }
}
