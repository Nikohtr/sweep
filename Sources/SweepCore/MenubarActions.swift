import CoreGraphics

/// What a gesture on the empty menu bar does.
public enum MenubarAction: Sendable, Equatable {
    /// Unsnap every snapped window on this screen, or on all screens (secondary modifier).
    case unsnapAll(allScreens: Bool)
    case minimizeAll(allScreens: Bool)
    case unminimizeAll(allScreens: Bool)
    /// Move every snapped window on this screen to the next screen in that direction (screen modifier).
    case moveSnappedToScreen(Direction)
    /// Activate the next (or previous) app, like ⌘⇥ / ⌘⇧⇥.
    case switchApp(forward: Bool)
}

/// Rules: double tap the menu bar to unsnap all windows on the current screen;
/// with the secondary modifier, on all screens. Swipe down/up minimizes/unminimizes all windows: once for the
/// current screen, twice or with the secondary modifier for all screens.
public enum MenubarActions {
    public static func finalAction(for steps: [Primitive], roles: Set<ModifierRole>) -> MenubarAction? {
        let moves = steps.filter { $0 != .pause }
        if roles.contains(.screen) {
            if moves.count == 1, case .swipe(let d) = moves[0] { return .moveSnappedToScreen(d) }
            return nil
        }
        switch moves {
        case [.tap]: return .unsnapAll(allScreens: roles.contains(.secondary))
        case [.swipe(.down)]: return .minimizeAll(allScreens: roles.contains(.secondary))
        case [.swipe(.down), .swipe(.down)]: return .minimizeAll(allScreens: true)
        case [.swipe(.up)]: return .unminimizeAll(allScreens: roles.contains(.secondary))
        case [.swipe(.up), .swipe(.up)]: return .unminimizeAll(allScreens: true)
        case [.swipe(.right)]: return .switchApp(forward: true)
        case [.swipe(.left)]: return .switchApp(forward: false)
        default: return nil
        }
    }
}

public enum MenubarPlan {
    /// Windows (by key, with their current frames) to unsnap: those shown mostly on `screenIndex`,
    /// or those on any screen. Order follows `current`.
    public static func unsnapTargets<Key>(current: [(Key, CGRect)], screens: [CGRect], screenIndex: Int,
                                          allScreens: Bool) -> [Key] {
        current.compactMap { key, frame in
            guard let i = SnapLayout.screenIndex(for: frame, screens: screens) else { return nil }
            return allScreens || i == screenIndex ? key : nil
        }
    }
}

/// The held-open app switcher on the menu bar (tap and hold, then move).
/// The app holds ⌘ while the gesture lasts, like holding ⌘ and pressing Tab.
public enum MenubarSwitcher {
    public enum Event: Sendable, Equatable {
        /// Press ⌘ and Tab: the switcher appears.
        case open
        /// Tab (forward) or ⇧Tab with ⌘ still held.
        case step(forward: Bool)
        /// Release ⌘: switch to the selected app.
        case close
        /// Esc, then release ⌘: hide the switcher without switching.
        case dismiss
    }

    public static func live(newStep: Primitive, steps: [Primitive]) -> Event? {
        guard steps.first == .hold else { return nil }
        if newStep == .hold { return steps == [.hold] ? .open : nil }
        if case .swipe(let d) = newStep, d == .left || d == .right { return .step(forward: d == .right) }
        return nil
    }

    public static func end(steps: [Primitive]) -> Event? { steps.first == .hold ? .close : nil }

    public static func cancel(steps: [Primitive]) -> Event? { steps.first == .hold ? .dismiss : nil }
}
