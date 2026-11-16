import AppKit
import ApplicationServices
import SweepCore

/// An app's windows through the Accessibility API.
@MainActor
enum AppWindows {
    /// Every window of the app. Each element gets the window-action timeout.
    static func windows(of app: NSRunningApplication) -> [AXUIElement] {
        let element = AXHitTester.forAction(AXUIElementCreateApplication(app.processIdentifier))
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement] else { return [] }
        return list.map(AXHitTester.forAction)
    }

    static func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        let element = AXHitTester.forAction(AXUIElementCreateApplication(app.processIdentifier))
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return AXHitTester.forAction(v as! AXUIElement)
    }

    static func isMinimized(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success
            && (value as? NSNumber)?.boolValue == true
    }

    /// Minimize (`true`) or bring back (`false`) windows picked by `WindowPick`.
    static func setMinimized(_ minimize: Bool, all: Bool, app: NSRunningApplication) {
        let list = windows(of: app)
        let states = list.map(isMinimized)
        let targets: [Int]
        if minimize {
            let focused = focusedWindow(of: app).flatMap { f in list.firstIndex { CFEqual($0, f) } }
            targets = WindowPick.minimizeTargets(minimized: states, focused: focused, all: all)
        } else {
            targets = WindowPick.unminimizeTargets(minimized: states, all: all)
            if !targets.isEmpty { app.activate() }
        }
        for i in targets {
            AXUIElementSetAttributeValue(list[i], kAXMinimizedAttribute as CFString,
                                         minimize ? kCFBooleanTrue : kCFBooleanFalse)
        }
    }

    /// Raises the next window of the app (see `WindowPick.cycleTarget`) and activates the app.
    static func cycle(forward: Bool, app: NSRunningApplication) {
        let list = windows(of: app)
        guard let i = WindowPick.cycleTarget(minimized: list.map(isMinimized), forward: forward) else {
            app.activate()
            return
        }
        AXUIElementPerformAction(list[i], kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(list[i], kAXMainAttribute as CFString, kCFBooleanTrue)
        app.activate()
    }

    /// Minimize (or bring back) the windows of every regular app on one screen, or on all screens.
    static func setMinimizedEverywhere(_ minimize: Bool, screenIndex: Int?, allScreens: Bool) {
        guard allScreens || screenIndex != nil else { return }
        let screens = AXHitTester.screens().map(\.frame)
        let me = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != me
        }
        // Only windows in the opposite state can change.
        let candidates: [(AXUIElement, CGRect)] = apps.flatMap { app in
            windows(of: app).compactMap { w in
                isMinimized(w) == minimize ? nil : AXHitTester.frame(w).map { (w, $0) }
            }
        }
        let targets = MenubarPlan.unsnapTargets(current: candidates, screens: screens,
                                                screenIndex: screenIndex ?? 0, allScreens: allScreens)
        for w in targets {
            AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, minimize ? kCFBooleanTrue : kCFBooleanFalse)
        }
    }
}
