import Foundation
import Testing
@testable import SweepCore

/// Per-gesture switches for Dock and menu bar gestures.
@Suite struct DockMenuToggleTests {
    typealias K = DockMenuGestureKind

    @Test(arguments: [
        (AppAction.quit, K.dockQuit), (.hide, .dockHide), (.hideOthers, .dockHide),
        (.minimizeFront, .dockMinimize), (.minimizeAll, .dockMinimize), (.unminimizeLast, .dockMinimize),
        (.unminimizeAll, .dockMinimize), (.cycleWindows(forward: true), .dockCycle), (.activate, .dockActivate),
    ])
    func kindOfDockAction(action: AppAction, kind: K) {
        #expect(K.of(action) == kind)
    }

    @Test(arguments: [
        (MenubarAction.unsnapAll(allScreens: false), K.menubarUnsnap),
        (.minimizeAll(allScreens: true), .menubarMinimizeAll), (.unminimizeAll(allScreens: false), .menubarRestoreAll),
        (.moveSnappedToScreen(.left), .menubarScreens), (.switchApp(forward: true), .menubarSwitchApps),
    ])
    func kindOfMenubarAction(action: MenubarAction, kind: K) {
        #expect(K.of(action) == kind)
    }

    @Test func everyKindIsListedOnceInTheTab() {
        #expect(K.dock + K.menubar == K.allCases)
        #expect(Set(K.allCases.map(\.title)).count == K.allCases.count)
    }

    @Test func allOnByDefault() {
        let s = SweepSettings()
        #expect(s.disabledDockMenuGestures.isEmpty)
        #expect(DockActions.allowed(.quit, settings: s) == .quit)
        #expect(MenubarActions.allowed(.minimizeAll(allScreens: false), settings: s) == .minimizeAll(allScreens: false))
        #expect(MenubarSwitcher.allowed(.open, settings: s) == .open)
    }

    @Test func turnedOffKindGivesNoAction() {
        var s = SweepSettings()
        s.disabledDockMenuGestures = [.dockQuit, .menubarMinimizeAll, .menubarSwitchApps]
        #expect(DockActions.allowed(.quit, settings: s) == nil)
        #expect(DockActions.allowed(.hide, settings: s) == .hide)
        #expect(MenubarActions.allowed(.minimizeAll(allScreens: true), settings: s) == nil)
        #expect(MenubarActions.allowed(.unminimizeAll(allScreens: true), settings: s) == .unminimizeAll(allScreens: true))
        // The hold-to-switch app switcher belongs to "switch apps" too.
        #expect(MenubarSwitcher.allowed(.open, settings: s) == nil)
        #expect(MenubarSwitcher.allowed(.step(forward: true), settings: s) == nil)
        #expect(DockActions.allowed(nil, settings: s) == nil)
    }

    @Test func oldStoredSettingsStillDecodeWithEverythingOn() throws {
        // Settings saved by an older version: no "disabledDockMenuGestures" key.
        let old = #"{"gesturesEnabled":true,"sensitivity":2,"disabledGestures":["close"],"ignoredApps":["com.example.a"]}"#
        let s = try JSONDecoder().decode(SweepSettings.self, from: Data(old.utf8))
        #expect(s.sensitivity == 2)
        #expect(s.disabledGestures == [.close])
        #expect(s.ignoredApps == ["com.example.a"])
        #expect(s.disabledDockMenuGestures.isEmpty)
    }

    @Test func unknownKindNamesAreSkipped() throws {
        // A newer version may add kinds; one unknown name must not throw the whole settings away.
        let json = #"{"disabledDockMenuGestures":["dockQuit","dockFutureThing"],"sensitivity":4}"#
        let s = try JSONDecoder().decode(SweepSettings.self, from: Data(json.utf8))
        #expect(s.disabledDockMenuGestures == [.dockQuit])
        #expect(s.sensitivity == 4)
    }

    @Test func roundTrip() throws {
        var s = SweepSettings()
        s.disabledDockMenuGestures = [.dockCycle, .menubarScreens]
        let back = try JSONDecoder().decode(SweepSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
