/// One page of the welcome tutorial. Gesture rows reuse `GestureHelp`.
public struct TutorialPage: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Text, art and gesture rows.
        case info
        /// The Accessibility ask: live status and an Allow button.
        case permission
    }

    public let title: String
    public let body: String
    public let rows: [GestureHelpRow]
    /// Base name of the page's illustration in the app's resources, or nil for none.
    public let art: String?
    public let kind: Kind

    public init(title: String, body: String, rows: [GestureHelpRow], art: String?, kind: Kind = .info) {
        self.title = title
        self.body = body
        self.rows = rows
        self.art = art
        self.kind = kind
    }
}

public enum Tutorial {
    public static let pages: [TutorialPage] = [
        TutorialPage(title: "Windows, in one motion",
                     body: "Sweep lets you place, tidy and close windows with two fingers on the trackpad. "
                         + "This short tour takes a minute.",
                     rows: [], art: "welcome-hero"),
        TutorialPage(title: "Let Sweep move your windows",
                     body: "macOS asks you to allow this once, in Privacy & Security › Accessibility. Sweep uses "
                         + "it only to find the window under your fingers and to move, resize, minimize or close it. "
                         + "Nothing leaves your Mac.",
                     rows: [], art: "gesture-permission", kind: .permission),
        TutorialPage(title: "Swipe on a titlebar to snap",
                     body: "Put two fingers on a window's titlebar and swipe. Left or right gives a half, and up "
                         + "fills the screen. Swipe across and then up or down for a quarter. Double tap to unsnap.",
                     rows: [], art: "gesture-snap"),
        TutorialPage(title: "Pinch, swipe, done",
                     body: "Each of these happens when you lift your fingers.",
                     rows: GestureHelp.titlebar.filter { $0.role == nil }, art: "gesture-close"),
        TutorialPage(title: "The Dock and the menu bar",
                     body: "On a Dock icon, gestures control that app: double tap to hide it, swipe down to minimize "
                         + "it. On an empty part of the menu bar, they act on all the windows on the screen. "
                         + "Pinch in to quit and swipe down to minimize all start off: turn them on in Settings › Gestures.",
                     rows: GestureHelp.menubar.filter { $0.role == nil }.prefix(3).map { $0 },
                     art: "gesture-dock-menubar"),
        TutorialPage(title: "Hold a key for more",
                     body: "Hold a key while you swipe to get more: thirds and ninths, other displays and Spaces, "
                         + "hiding apps. Pick your keys in Settings › Keys.",
                     rows: GestureHelp.titlebar.filter { $0.role != nil }, art: "gesture-modifiers"),
    ]

    public static func shouldShowOnLaunch(settings: SweepSettings) -> Bool { !settings.tutorialSeen }

    public static func next(after index: Int) -> Int? { index + 1 < pages.count ? index + 1 : nil }

    public static func previous(before index: Int) -> Int? { index > 0 ? index - 1 : nil }

    /// The forward button's text: skip is offered only on the permission page while trust is missing.
    public static func nextLabel(at index: Int, granted: Bool) -> String {
        if next(after: index) == nil { return "Start Sweeping" }
        return pages[index].kind == .permission && !granted ? "Skip for Now" : "Next"
    }
}
