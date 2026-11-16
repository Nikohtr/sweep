import CoreGraphics

/// What a gesture on a tab does.
public enum TabAction: Sendable, Equatable {
    case closeTab
    case newTab
    /// Tap and hold: drag the tab out into its own window.
    case detachTab

    /// The key chord the app posts, or nil when the action is done with the mouse.
    /// ⌘W closes the selected tab in most apps.
    public var chord: KeyChord? {
        switch self {
        case .detachTab: return nil
        case .closeTab: return KeyChord(keyCode: 13, modifiers: [.command])
        case .newTab: return KeyChord(keyCode: 17, modifiers: [.command])   // ⌘T
        }
    }

    /// Close acts on the tab under the fingers, so that tab is selected first; a new tab needs no selection.
    public var selectsTabFirst: Bool { self == .closeTab }
}

public enum TabActions {
    /// Live: the first step being a hold detaches the tab.
    public static func liveAction(newStep: Primitive, steps: [Primitive]) -> TabAction? {
        newStep == .hold && steps == [.hold] ? .detachTab : nil
    }

    /// After a detach, the rest of the gesture is a titlebar gesture on the new window (same rule as the Dock).
    public static func chainedSteps(_ steps: [Primitive]) -> [Primitive]? {
        DockActions.chainedSteps(steps)
    }

    /// On lift. Nil means "not a tab gesture": the app treats it as a titlebar gesture on the window.
    public static func finalAction(for steps: [Primitive]) -> TabAction? {
        switch steps.filter({ $0 != .pause }) {
        case [.pinchIn]: return .closeTab
        case [.pinchOut]: return .newTab
        default: return nil
        }
    }
}

/// Drags a tab out of its tab bar with synthetic mouse events (our method, public events only).
/// Most tabbed apps open a dragged-out tab as a new window.
public enum TabDetachPlan {
    public static let dragDistance: CGFloat = 120

    public static func steps(tab: CGRect, cursor: CGPoint) -> [SpaceMovePlan.Step] {
        let start = CGPoint(x: tab.midX, y: tab.midY)
        let drags = (1...4).map { CGPoint(x: start.x, y: start.y + dragDistance * CGFloat($0) / 4) }
        return [.mouseDown(start)] + drags.map { .drag($0) }
            + [.wait(0.2), .mouseUp(drags[drags.count - 1]), .warp(cursor)]
    }
}

/// Kinds of tabbed apps with their own on/off switch for tab gestures.
public enum TabApp: String, Codable, CaseIterable, Sendable {
    case native, safari, arc, chrome, xcode, vscode

    public static func of(bundleID: String?) -> TabApp {
        switch bundleID {
        case "com.apple.Safari": return .safari
        case "company.thebrowser.Browser": return .arc
        case "com.google.Chrome": return .chrome
        case "com.apple.dt.Xcode": return .xcode
        case "com.microsoft.VSCode": return .vscode
        default: return .native
        }
    }

    public var title: String {
        switch self {
        case .native: return "Native tabs (Finder, Terminal, …)"
        case .safari: return "Safari"
        case .arc: return "Arc"
        case .chrome: return "Chrome"
        case .xcode: return "Xcode"
        case .vscode: return "VS Code"
        }
    }
}
