import AppKit
import ApplicationServices
import Foundation
import SweepCore

/// An AX window element usable as a dictionary key (CFEqual / CFHash).
struct WindowKey: Hashable {
    let element: AXUIElement
    static func == (a: WindowKey, b: WindowKey) -> Bool { CFEqual(a.element, b.element) }
    func hash(into h: inout Hasher) { h.combine(CFHash(element)) }
}

/// Applies window actions through the Accessibility API.
@MainActor
enum WindowMover {
    /// Frames from before the first snap, for unsnap.
    static var memory = UnsnapMemory<WindowKey>()
    /// Each snapped window's frame right after its snap, for resizing neighbours together.
    static var snappedFrames: [WindowKey: CGRect] = [:]
    /// Frames from before each move, resize or snap, for Undo Window Move.
    static var undo = UndoStack<WindowKey>()
    /// The current gesture or key press. The app moves it on when a gesture ends.
    static var undoGroup = 0

    /// After a mouse drag ends: if a snapped window was resized at a shared edge, move its neighbours' edges.
    static func resizeAdjacentAfterDrag() {
        guard !snappedFrames.isEmpty else { return }
        var current: [WindowKey: CGRect] = [:]
        for key in snappedFrames.keys {
            if let f = AXHitTester.frame(key.element) { current[key] = f }
        }
        let known = snappedFrames.filter { current[$0.key] != nil }
        let adjusted = AdjacentResize.adjust(snapped: known, current: current)
        for (key, frame) in adjusted { setFrame(frame, of: key.element) }
        snappedFrames = current.merging(adjusted) { _, new in new }
    }

    /// Runs an action as a plan (see `ActionPlan`), so fullscreen windows can be minimized.
    static func run(_ action: WindowAction, on window: AXUIElement, settings: SweepSettings) {
        AXHitTester.forAction(window)   // Wait at most AXTimeouts.windowAction per call
        if UndoPolicy.records(action), let before = AXHitTester.frame(window) {
            undo.record(WindowKey(element: window), frame: before, group: undoGroup)
        }
        let plan = ActionPlan.steps(for: action, isFullscreen: isFullscreen(window),
                                    hasOtherScreen: AXHitTester.screens().count >= 2)
        execute(plan[...], on: window, settings: settings)
    }

    private static func execute(_ steps: ArraySlice<ActionPlan.Step>, on window: AXUIElement,
                                settings: SweepSettings) {
        guard let step = steps.first else { return }
        switch step {
        case .perform(let action):
            perform(action, on: window, settings: settings)
            execute(steps.dropFirst(), on: window, settings: settings)
        case .wait(let seconds):
            let rest = steps.dropFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                MainActor.assumeIsolated { execute(rest, on: window, settings: settings) }
            }
        }
    }

    static func afterSnap(_ window: AXUIElement, steps: [AfterSnap.Step]) {
        AXHitTester.forAction(window)
        for step in steps {
            switch step {
            case .activate:
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                var pid: pid_t = 0
                if AXUIElementGetPid(window, &pid) == .success {
                    NSRunningApplication(processIdentifier: pid)?.activate()
                }
            case .moveCursor:
                if let frame = AXHitTester.frame(window) {
                    CGWarpMouseCursorPosition(AfterSnap.cursorTarget(frame: frame))
                }
            }
        }
    }

    /// Reads (never writes) the system Stage Manager switch.
    static func stageManagerOn() -> Bool {
        CFPreferencesCopyAppValue("GloballyEnabled" as CFString, "com.apple.WindowManager" as CFString)
            .flatMap { $0 as? Bool } ?? false
    }

    static func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success
            && (value as? NSNumber)?.boolValue == true
    }

    static func perform(_ action: WindowAction, on window: AXUIElement, settings: SweepSettings) {
        switch action {
        case .snap(let target) where NativeTiling.useNative(target: target, settings: settings):
            // Let macOS tile the window; it must be the front window for the system shortcut.
            guard let current = AXHitTester.frame(window), let chord = NativeTiling.chord(for: target) else { return }
            memory.willSnap(WindowKey(element: window), from: current)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            var pid: pid_t = 0
            if AXUIElementGetPid(window, &pid) == .success { NSRunningApplication(processIdentifier: pid)?.activate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { KeyPoster.post(chord) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated { snappedFrames[WindowKey(element: window)] = AXHitTester.frame(window) }
            }
        case .snap(let target):
            guard let current = AXHitTester.frame(window) else { return }
            let screens = AXHitTester.screens()
            guard let i = SnapLayout.screenIndex(for: current, screens: screens.map(\.frame)) else { return }
            memory.willSnap(WindowKey(element: window), from: current)
            setFrame(SnapLayout.frame(for: target, in: screens[i].visible, settings: settings,
                                      stageManagerOn: stageManagerOn()), of: window)
            snappedFrames[WindowKey(element: window)] = AXHitTester.frame(window)
        case .center:
            guard let current = AXHitTester.frame(window) else { return }
            let screens = AXHitTester.screens()
            guard let i = SnapLayout.screenIndex(for: current, screens: screens.map(\.frame)) else { return }
            let size = memory.takeOriginal(WindowKey(element: window))?.size ?? current.size
            snappedFrames[WindowKey(element: window)] = nil
            let usable = SnapLayout.usableFrame(visible: screens[i].visible, stageManagerOn: stageManagerOn(),
                                                offset: CGFloat(settings.stageManagerOffset))
            setFrame(SnapLayout.centered(size: size, in: usable), of: window)
        case .hideApp, .hideOtherApps:
            var pid: pid_t = 0
            guard AXUIElementGetPid(window, &pid) == .success,
                  let app = NSRunningApplication(processIdentifier: pid) else { return }
            if action == .hideApp {
                app.hide()
            } else {
                let running = NSWorkspace.shared.runningApplications
                let refs = running.map { AppRef(id: String($0.processIdentifier), regular: $0.activationPolicy == .regular) }
                let hide = Set(DockActions.othersToHide(target: String(pid), running: refs,
                                                        selfID: String(ProcessInfo.processInfo.processIdentifier)))
                running.filter { hide.contains(String($0.processIdentifier)) }.forEach { $0.hide() }
            }
        case .moveToScreen(let direction):
            guard let current = AXHitTester.frame(window) else { return }
            let screens = AXHitTester.screens()
            guard let i = SnapLayout.screenIndex(for: current, screens: screens.map(\.frame)),
                  let j = ScreenLayout.neighbor(of: i, direction: direction, screens: screens.map(\.frame))
            else { return }
            let moved = ScreenLayout.move(frame: current, from: screens[i].visible, to: screens[j].visible)
            setFrame(moved, of: window)
            if settings.screensMoveCursor {
                CGWarpMouseCursorPosition(AfterSnap.cursorTarget(frame: AXHitTester.frame(window) ?? moved))
            }
        case .moveToOtherScreen:
            guard let current = AXHitTester.frame(window) else { return }
            let screens = AXHitTester.screens()
            guard let i = SnapLayout.screenIndex(for: current, screens: screens.map(\.frame)),
                  let j = ScreenLayout.otherScreen(of: i, count: screens.count) else { return }
            setFrame(ScreenLayout.move(frame: current, from: screens[i].visible, to: screens[j].visible), of: window)
        case .moveToSpace(let direction):
            guard let frame = AXHitTester.frame(window) else { return }
            let cursor = CGEvent(source: nil)?.location ?? .zero
            let grab = SpaceMovePlan.grabPoint(frame: frame)
            SpaceMover.run(SpaceMovePlan.steps(grab: grab, direction: direction, cursor: cursor)[...])
        case .fullscreenOnOtherScreen:
            // A plan, not one step: `run` expands it (move, wait, fullscreen).
            run(action, on: window, settings: settings)
        case .minimize:
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        case .toggleFullscreen:
            let isOn = isFullscreen(window)
            AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, isOn ? kCFBooleanFalse : kCFBooleanTrue)
        case .close:
            // Press the window's own close button, so the app can ask to save first.
            var button: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button) == .success,
                  let b = button, CFGetTypeID(b) == AXUIElementGetTypeID() else { return }
            AXUIElementPerformAction(b as! AXUIElement, kAXPressAction as CFString)
        }
    }

    /// Puts the most recently moved window that still exists back where it was. False when there is none.
    @discardableResult
    static func undoLast() -> Bool {
        guard let entry = undo.popAlive({ AXHitTester.frame(AXHitTester.forAction($0.element)) != nil }) else {
            return false
        }
        memory.forget(entry.key)          // its pre-snap frame is no longer the one to return to
        snappedFrames[entry.key] = nil
        setFrame(entry.frame, of: entry.key.element)
        undoGroup += 1
        return true
    }

    /// Sets position, then size, then position again: some apps clamp the size against
    /// the old position, so the second move fixes the final place.
    static func setFrame(_ frame: CGRect, of window: AXUIElement) {
        var origin = frame.origin
        var size = frame.size
        guard let pos = AXValueCreate(.cgPoint, &origin), let sz = AXValueCreate(.cgSize, &size) else { return }
        AXHitTester.forAction(window)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
    }
}
