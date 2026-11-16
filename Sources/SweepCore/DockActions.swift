/// What a gesture on a Dock icon (or the app menu) does to that app.
public enum AppAction: Sendable, Equatable {
    case quit
    case hide
    /// Hide every other regular app (secondary modifier).
    case hideOthers
    case minimizeFront, minimizeAll, unminimizeLast, unminimizeAll
    /// Bring the app's next (or previous) window to the front.
    case cycleWindows(forward: Bool)
    /// Activate the app and chain its front window (tap and hold).
    case activate
}

/// Picks which of an app's windows (in AX order) to minimize or bring back.
public enum WindowPick {
    /// The focused window if it is visible, else the first visible one; or every visible one.
    public static func minimizeTargets(minimized: [Bool], focused: Int?, all: Bool) -> [Int] {
        let visible = minimized.indices.filter { !minimized[$0] }
        if all { return visible }
        if let f = focused, visible.contains(f) { return [f] }
        return visible.first.map { [$0] } ?? []
    }

    /// Window to raise when cycling (front-to-back order, minimized ones skipped). Forward raises the
    /// backmost visible window, so repeated swipes visit every window; backward raises the one right
    /// behind the front window.
    public static func cycleTarget(minimized: [Bool], forward: Bool) -> Int? {
        let visible = minimized.indices.filter { !minimized[$0] }
        guard visible.count >= 2 else { return nil }
        return forward ? visible.last : visible[1]
    }

    /// The last minimized window, or every minimized one.
    public static func unminimizeTargets(minimized: [Bool], all: Bool) -> [Int] {
        let hidden = minimized.indices.filter { minimized[$0] }
        if all { return hidden }
        return hidden.last.map { [$0] } ?? []
    }
}

/// A running app, reduced to what the hide rules need.
public struct AppRef: Sendable, Equatable {
    public var id: String
    /// A normal app with a Dock icon (not a background agent).
    public var regular: Bool
    public init(id: String, regular: Bool) { self.id = id; self.regular = regular }
}

/// Maps gesture steps made on a Dock icon to an app action.
/// Rules: pinch in quits the application; double tap hides it, and with the
/// secondary modifier hides all other apps; swipe down minimizes the front window and swipe up brings back the
/// last one (secondary: all windows).
public enum DockActions {
    /// Live actions while the fingers are down (none that depend only on the step list).
    public static func action(for steps: [Primitive], roles: Set<ModifierRole>) -> AppAction? {
        nil
    }

    /// Live action for one new step: in a gesture made only of horizontal swipes, each new swipe step
    /// cycles the app's windows once (right = forward).
    public static func liveAction(newStep: Primitive, steps: [Primitive], roles: Set<ModifierRole>) -> AppAction? {
        if roles.contains(.superKey) { return nil }   // super: a window gesture (see superWindowSteps)
        if newStep == .hold, steps.first == .hold, steps.count == 1 { return .activate }
        guard case .swipe(let d) = newStep, d == .left || d == .right else { return nil }
        let horizontalOnly = steps.allSatisfy { step in
            if step == .pause { return true }
            if case .swipe(let x) = step { return x == .left || x == .right }
            return false
        }
        return horizontalOnly ? .cycleWindows(forward: d == .right) : nil
    }

    /// The action to run when the fingers lift. Quitting is never live, so a slip cannot quit an app.
    public static func finalAction(for steps: [Primitive], roles: Set<ModifierRole>) -> AppAction? {
        if roles.contains(.superKey) { return nil }
        switch steps.filter({ $0 != .pause }) {
        case [.pinchIn]: return .quit
        case [.tap]: return roles.contains(.secondary) ? .hideOthers : .hide
        case [.swipe(.down)]: return roles.contains(.secondary) ? .minimizeAll : .minimizeFront
        case [.swipe(.up)]: return roles.contains(.secondary) ? .unminimizeAll : .unminimizeLast
        default: return nil
        }
    }

    /// Tap-and-hold on a Dock icon chains the app's front window: the steps after the hold are a
    /// titlebar gesture on that window.
    /// Nil when the gesture did not start with a hold.
    /// Super modifier on a Dock icon: the whole gesture is a titlebar gesture on the app's front window.
    /// Nil without the super role.
    public static func superWindowSteps(_ steps: [Primitive], roles: Set<ModifierRole>) -> [Primitive]? {
        roles.contains(.superKey) ? steps : nil
    }

    public static func chainedSteps(_ steps: [Primitive]) -> [Primitive]? {
        steps.first == .hold ? Array(steps.dropFirst()) : nil
    }

    /// Which apps "hide others" hides: every other regular app, never the target or Sweep itself.
    public static func othersToHide(target: String, running: [AppRef], selfID: String) -> [String] {
        running.filter { $0.regular && $0.id != target && $0.id != selfID }.map(\.id)
    }
}
