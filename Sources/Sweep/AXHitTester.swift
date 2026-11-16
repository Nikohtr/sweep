import AppKit
import ApplicationServices
import SweepCore

/// One hit test's Accessibility reads. After the first timed-out call it makes no more calls
/// (see `HitTestGuard`), so a hung app costs at most one `AXTimeouts.hitTest` wait.
@MainActor
final class AXReader {
    private(set) var guardState = HitTestGuard()

    private func record(_ err: AXError) -> Bool {
        guardState.record(AXCallOutcome(err))
        return err == .success
    }

    func element(at cursor: CGPoint) -> AXUIElement? {
        guard guardState.mayCall else { return nil }
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(AXHitTester.systemWide, Float(cursor.x), Float(cursor.y), &element)
        return record(err) ? element : nil
    }

    func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        guard guardState.mayCall else { return nil }
        var value: CFTypeRef?
        return record(AXUIElementCopyAttributeValue(element, attribute as CFString, &value)) ? value : nil
    }

    func string(_ element: AXUIElement, _ attribute: String) -> String? { value(element, attribute) as? String }

    func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (value(element, attribute) as? NSNumber)?.boolValue
    }

    func elementValue(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let v = value(element, attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = value(element, kAXPositionAttribute), let s = value(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
}

extension AXCallOutcome {
    init(_ err: AXError) {
        switch err {
        case .success: self = .success
        case .cannotComplete: self = .timedOut
        default: self = .failed
        }
    }
}

/// Finds what is under the cursor with the Accessibility API and builds a `HitInfo`.
@MainActor
enum AXHitTester {
    static let systemWide = AXUIElementCreateSystemWide()

    /// Sets the process-wide Accessibility timeout to the short hit-test value. Call once at launch.
    /// Window actions raise it again per element (`forAction`).
    static func installTimeouts() {
        AXUIElementSetMessagingTimeout(systemWide, AXTimeouts.hitTest)
    }

    /// Gives `element` the longer window-action timeout and returns it.
    @discardableResult
    static func forAction(_ element: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(element, AXTimeouts.windowAction)
        return element
    }

    /// What is under the cursor, and the window element so the app can move it later.
    /// Nil when the app under the cursor did not answer in time: no context, so the gesture drops.
    /// - Parameter cursor: global point, top-left origin (CGEvent location).
    static func hitWithWindow(at cursor: CGPoint) -> (info: HitInfo, window: AXUIElement?)? {
        let r = AXReader()
        let el = r.element(at: cursor)
        let role = el.flatMap { r.string($0, kAXRoleAttribute) }
        let window = el.flatMap { window(of: $0, role: role, r) }
        let info = HitInfo(cursor: cursor,
                           role: role,
                           windowFrame: window.flatMap(r.frame),
                           isFullscreen: window.flatMap { r.bool($0, "AXFullScreen") } ?? false,
                           screenVisibleFrame: visibleFrame(containing: cursor),
                           appBundleID: el.flatMap(bundleID),
                           isAppMenu: role == kAXMenuBarItemRole && el.map { isAppNameMenu($0, r) } == true,
                           isTab: el.map { isTab($0, role: role, r) } ?? false,
                           inMissionControl: el.map { inMissionControl($0, role: role, r) } ?? false,
                           screenFrame: screens().map(\.frame).first { $0.contains(cursor) })
        return r.guardState.context((info, window))
    }

    /// The element belongs to the Dock process (not a Dock icon) while Mission Control or App Exposé
    /// is showing. The Dock app has a child titled for the mode only then.
    private static func inMissionControl(_ element: AXUIElement, role: String?, _ r: AXReader) -> Bool {
        guard bundleID(of: element) == "com.apple.dock", !(role.map(dockItemRoles.contains) ?? false) else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let list = r.value(AXUIElementCreateApplication(pid), kAXChildrenAttribute) as? [AXUIElement]
        else { return false }
        return MissionControlState.isShowing(dockChildTitles: list.map { r.string($0, kAXTitleAttribute) })
    }

    private static let dockItemRoles: Set<String> = ["AXDockItem", "AXApplicationDockItem"]

    /// Title of the element under the cursor (a Mission Control thumbnail), if any.
    static func title(at cursor: CGPoint) -> String? {
        let r = AXReader()
        return r.element(at: cursor).flatMap { r.string($0, kAXTitleAttribute) }
    }

    /// Every regular app's windows with their titles, for matching a thumbnail to a window.
    static func titledWindows() -> [(window: AXUIElement, title: String)] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.flatMap { app in
            let r = AXReader()   // one per app: a hung app does not stop the others
            return AppWindows.windows(of: app).compactMap { w in r.string(w, kAXTitleAttribute).map { (w, $0) } }
        }
    }

    /// The tab element under the cursor, if any.
    static func tab(at cursor: CGPoint) -> AXUIElement? {
        let r = AXReader()
        guard let el = r.element(at: cursor), isTab(el, role: r.string(el, kAXRoleAttribute), r) else { return nil }
        return el
    }

    /// A tab: subrole AXTabButton, or a radio button inside a tab group (Safari, Finder, Terminal).
    private static func isTab(_ element: AXUIElement, role: String?, _ r: AXReader) -> Bool {
        if r.string(element, kAXSubroleAttribute) == "AXTabButton" { return true }
        guard role == kAXRadioButtonRole, let p = r.elementValue(element, kAXParentAttribute) else { return false }
        return r.string(p, kAXRoleAttribute) == kAXTabGroupRole
    }

    /// The running app behind the Dock icon at `cursor` (the icon's AXURL is the app bundle).
    static func dockApp(at cursor: CGPoint) -> NSRunningApplication? {
        let r = AXReader()
        guard let el = r.element(at: cursor),
              let url = (r.value(el, kAXURLAttribute) as? URL)?.standardizedFileURL else { return nil }
        return NSWorkspace.shared.runningApplications.first { $0.bundleURL?.standardizedFileURL == url }
    }

    /// True for the menu bar item right after the Apple menu (the app-name menu).
    private static func isAppNameMenu(_ item: AXUIElement, _ r: AXReader) -> Bool {
        guard let p = r.elementValue(item, kAXParentAttribute),
              let list = r.value(p, kAXChildrenAttribute) as? [AXUIElement], list.count > 1 else { return false }
        return CFEqual(list[1], item)
    }

    private static func bundleID(of element: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private static func window(of element: AXUIElement, role: String?, _ r: AXReader) -> AXUIElement? {
        role == kAXWindowRole ? element : r.elementValue(element, kAXWindowAttribute)
    }

    static func frame(_ element: AXUIElement) -> CGRect? { AXReader().frame(element) }

    /// Full and visible frames of every screen, top-left coordinates.
    static func screens() -> [(frame: CGRect, visible: CGRect)] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.map {
            (OriginClassifier.topLeft($0.frame, primaryScreenHeight: primaryHeight),
             OriginClassifier.topLeft($0.visibleFrame, primaryScreenHeight: primaryHeight))
        }
    }

    /// Visible frame (top-left coordinates) of the screen under the cursor.
    private static func visibleFrame(containing cursor: CGPoint) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            let full = OriginClassifier.topLeft(screen.frame, primaryScreenHeight: primaryHeight)
            if full.contains(cursor) {
                return OriginClassifier.topLeft(screen.visibleFrame, primaryScreenHeight: primaryHeight)
            }
        }
        return .null
    }
}
