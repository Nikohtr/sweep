import CoreGraphics

/// Where a gesture was made. Decides which gesture table applies.
public enum Origin: Sendable, Equatable {
    case titlebar
    case toolbar
    /// Anywhere on a window (super modifier held).
    case window
    case dock
    case menubar
    /// The menu bar item with the frontmost app's name (next to the Apple menu). Takes Dock gestures.
    case appMenu
    /// A tab in a window's tab bar. Takes tab gestures; other gestures act on the window.
    case tab
    /// A window thumbnail while Mission Control or App Exposé is showing.
    case missionControl
    /// A Space in the Mission Control Spaces bar.
    case missionControlSpace
}

/// What the app found under the cursor. All rects are global, top-left origin (AX coordinates).
public struct HitInfo: Sendable, Equatable {
    public var cursor: CGPoint
    public var role: String?
    public var windowFrame: CGRect?
    public var isFullscreen: Bool
    public var screenVisibleFrame: CGRect
    /// Bundle ID of the app that owns the element under the cursor, if known.
    public var appBundleID: String?
    /// The element is the app-name menu in the menu bar.
    public var isAppMenu: Bool
    /// The element is a tab in a tab bar.
    public var isTab: Bool
    /// Mission Control or App Exposé is showing and the element belongs to it.
    public var inMissionControl: Bool
    /// Full frame of the screen under the cursor (top-left), when known.
    public var screenFrame: CGRect?

    public init(cursor: CGPoint, role: String?, windowFrame: CGRect?, isFullscreen: Bool,
                screenVisibleFrame: CGRect, appBundleID: String? = nil, isAppMenu: Bool = false, isTab: Bool = false,
                inMissionControl: Bool = false, screenFrame: CGRect? = nil) {
        self.screenFrame = screenFrame
        self.isTab = isTab
        self.inMissionControl = inMissionControl
        self.appBundleID = appBundleID
        self.isAppMenu = isAppMenu
        self.cursor = cursor
        self.role = role
        self.windowFrame = windowFrame
        self.isFullscreen = isFullscreen
        self.screenVisibleFrame = screenVisibleFrame
    }
}

/// Decides the gesture origin from a hit test.
public enum OriginClassifier {
    /// Height of the plain titlebar band, from the window's top edge.
    public static let titlebarHeight: CGFloat = 23
    /// Band for fullscreen windows: the revealed titlebar slides in under the menu bar
    /// (about 24 pt menu bar + 28 pt titlebar).
    public static let fullscreenBand: CGFloat = 52
    /// Deepest point below the window top that still counts as toolbar.
    public static let toolbarLimit: CGFloat = 120

    /// Roles that are "background" in a toolbar area: safe to swipe on.
    static let toolbarRoles: Set<String> = ["AXToolbar", "AXGroup", "AXWindow", "AXStaticText", "AXImage", "AXUnknown"]
    /// Roles that need scrolling or text input. Never take gestures from them.
    static let blockedRoles: Set<String> = ["AXScrollArea", "AXScrollBar", "AXTextArea", "AXTextField",
                                            "AXSplitter", "AXWebArea", "AXTable", "AXOutline", "AXList"]
    static let dockRoles: Set<String> = ["AXDockItem", "AXApplicationDockItem"]

    public static func classify(_ hit: HitInfo, superModifier: Bool = false) -> Origin? {
        let role = hit.role ?? "AXUnknown"
        if hit.inMissionControl {
            if let screen = hit.screenFrame, MissionControlSpaces.isInSpacesBar(cursor: hit.cursor, screenFrame: screen) {
                return .missionControlSpace
            }
            return .missionControl
        }
        if dockRoles.contains(role) { return .dock }
        if !hit.screenVisibleFrame.contains(hit.cursor) {
            // Above the visible frame is the menu bar strip. Only its empty area counts.
            if hit.cursor.y < hit.screenVisibleFrame.minY, role == "AXMenuBar" { return .menubar }
            if hit.cursor.y < hit.screenVisibleFrame.minY, role == "AXMenuBarItem", hit.isAppMenu { return .appMenu }
            return nil
        }
        guard let frame = hit.windowFrame, frame.contains(hit.cursor) else { return nil }
        if superModifier { return .window }
        if hit.isTab { return .tab }
        if blockedRoles.contains(role) { return nil }
        let depth = hit.cursor.y - frame.minY
        if hit.isFullscreen {
            // No toolbar area to use: below the revealed titlebar is content.
            return depth <= fullscreenBand ? .titlebar : nil
        }
        if depth <= titlebarHeight { return .titlebar }
        if depth <= toolbarLimit, toolbarRoles.contains(role) { return .toolbar }
        return nil
    }

    /// Converts an AppKit rect (bottom-left origin on the primary screen) to top-left global coordinates.
    public static func topLeft(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
