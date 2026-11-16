import CoreGraphics
import Testing
@testable import SweepCore

private let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let right = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

@Suite struct MenubarActionTests {
    @Test func doubleTapUnsnapsThisScreenOrAll() {
        #expect(MenubarActions.finalAction(for: [.tap], roles: []) == .unsnapAll(allScreens: false))
        #expect(MenubarActions.finalAction(for: [.tap], roles: [.secondary]) == .unsnapAll(allScreens: true))
        #expect(MenubarActions.finalAction(for: [.pinchIn], roles: []) == nil)
    }

    @Test func memoryListsItsWindows() {
        var m = UnsnapMemory<String>()
        m.willSnap("a", from: .zero)
        m.willSnap("b", from: .zero)
        #expect(Set(m.keys) == ["a", "b"])
    }

    @Test func targetsOnThisScreenOnly() {
        let current = [("a", CGRect(x: 0, y: 25, width: 720, height: 800)),
                       ("b", CGRect(x: 1440, y: 0, width: 960, height: 1080)),
                       ("c", CGRect(x: 720, y: 25, width: 720, height: 800))]
        #expect(MenubarPlan.unsnapTargets(current: current, screens: [main, right], screenIndex: 0, allScreens: false)
                == ["a", "c"])
        #expect(MenubarPlan.unsnapTargets(current: current, screens: [main, right], screenIndex: 0, allScreens: true)
                == ["a", "b", "c"])
    }

    @Test func windowsOffEveryScreenAreSkipped() {
        let current = [("x", CGRect(x: 9000, y: 0, width: 10, height: 10))]
        #expect(MenubarPlan.unsnapTargets(current: current, screens: [main], screenIndex: 0, allScreens: true).isEmpty)
    }
}

@Suite struct MenubarMinimizeTests {
    @Test func onceIsThisScreen() {
        #expect(MenubarActions.finalAction(for: [.swipe(.down)], roles: []) == .minimizeAll(allScreens: false))
        #expect(MenubarActions.finalAction(for: [.swipe(.up)], roles: []) == .unminimizeAll(allScreens: false))
    }

    @Test func twiceOrSecondaryIsAllScreens() {
        #expect(MenubarActions.finalAction(for: [.swipe(.down), .pause, .swipe(.down)], roles: [])
                == .minimizeAll(allScreens: true))
        #expect(MenubarActions.finalAction(for: [.swipe(.up), .pause, .swipe(.up)], roles: [])
                == .unminimizeAll(allScreens: true))
        #expect(MenubarActions.finalAction(for: [.swipe(.down)], roles: [.secondary]) == .minimizeAll(allScreens: true))
    }

    @Test func mixedSwipesDoNothing() {
        #expect(MenubarActions.finalAction(for: [.swipe(.down), .swipe(.up)], roles: []) == nil)
    }
}

@Suite struct MenubarScreensTests {
    @Test(arguments: Direction.allCases)
    func screenRoleSwipeMovesSnappedWindows(d: Direction) {
        #expect(MenubarActions.finalAction(for: [.swipe(d)], roles: [.screen]) == .moveSnappedToScreen(d))
    }

    @Test func screenRoleWinsOverMinimize() {
        #expect(MenubarActions.finalAction(for: [.swipe(.down)], roles: [.screen]) == .moveSnappedToScreen(.down))
        #expect(MenubarActions.finalAction(for: [.swipe(.down)], roles: []) == .minimizeAll(allScreens: false))
    }

    @Test func screenRoleOtherStepsDoNothing() {
        #expect(MenubarActions.finalAction(for: [.swipe(.left), .swipe(.up)], roles: [.screen]) == nil)
        #expect(MenubarActions.finalAction(for: [.tap], roles: [.screen]) == nil)
    }
}

@Suite struct MenubarAppSwitchTests {
    @Test func horizontalSwipeSwitchesApps() {
        #expect(MenubarActions.finalAction(for: [.swipe(.right)], roles: []) == .switchApp(forward: true))
        #expect(MenubarActions.finalAction(for: [.swipe(.left)], roles: []) == .switchApp(forward: false))
    }

    @Test func chordsAreCommandTab() {
        #expect(KeyChord.appSwitch(forward: true) == KeyChord(keyCode: 48, modifiers: [.command]))
        #expect(KeyChord.appSwitch(forward: false) == KeyChord(keyCode: 48, modifiers: [.command, .shift]))
    }
}
