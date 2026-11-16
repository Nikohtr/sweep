/// Dock and menu bar gestures that can be turned off one by one. A parallel list to `GestureKind`,
/// which covers window gestures. Stored by raw value, so the names never change.
public enum DockMenuGestureKind: String, Codable, CaseIterable, Sendable {
    case dockQuit, dockHide, dockMinimize, dockCycle, dockActivate
    case menubarUnsnap, menubarMinimizeAll, menubarRestoreAll, menubarScreens, menubarSwitchApps

    public static func of(_ action: AppAction) -> Self {
        switch action {
        case .quit: return .dockQuit
        case .hide, .hideOthers: return .dockHide
        case .minimizeFront, .minimizeAll, .unminimizeLast, .unminimizeAll: return .dockMinimize
        case .cycleWindows: return .dockCycle
        case .activate: return .dockActivate
        }
    }

    public static func of(_ action: MenubarAction) -> Self {
        switch action {
        case .unsnapAll: return .menubarUnsnap
        case .minimizeAll: return .menubarMinimizeAll
        case .unminimizeAll: return .menubarRestoreAll
        case .moveSnappedToScreen: return .menubarScreens
        case .switchApp: return .menubarSwitchApps
        }
    }

    /// Shown under "On a Dock icon" in the Gestures tab.
    public static let dock: [Self] = [.dockQuit, .dockHide, .dockMinimize, .dockCycle, .dockActivate]
    /// Shown under "On the menu bar" in the Gestures tab.
    public static let menubar: [Self] = [.menubarUnsnap, .menubarMinimizeAll, .menubarRestoreAll, .menubarScreens,
                                         .menubarSwitchApps]

    public var title: String {
        switch self {
        case .dockQuit: return "Quit the app (pinch in)"
        case .dockHide: return "Hide the app (double tap)"
        case .dockMinimize: return "Minimize or bring back windows (swipe down or up)"
        case .dockCycle: return "Go through its windows (swipe left or right)"
        case .dockActivate: return "Bring forward, then a window gesture (tap and hold)"
        case .menubarUnsnap: return "Unsnap all windows (double tap)"
        case .menubarMinimizeAll: return "Minimize all windows (swipe down)"
        case .menubarRestoreAll: return "Bring back all windows (swipe up)"
        case .menubarScreens: return "Move snapped windows to a display (with the Display key)"
        case .menubarSwitchApps: return "Switch apps (swipe left or right; tap and hold)"
        }
    }
}

extension SweepSettings {
    public func allows(_ kind: DockMenuGestureKind) -> Bool { !disabledDockMenuGestures.contains(kind) }
}

extension DockActions {
    /// `action`, or nil when its kind is turned off.
    public static func allowed(_ action: AppAction?, settings: SweepSettings) -> AppAction? {
        action.flatMap { settings.allows(.of($0)) ? $0 : nil }
    }
}

extension MenubarActions {
    public static func allowed(_ action: MenubarAction?, settings: SweepSettings) -> MenubarAction? {
        action.flatMap { settings.allows(.of($0)) ? $0 : nil }
    }
}

extension MenubarSwitcher {
    /// The hold-to-switch app switcher is part of "switch apps".
    public static func allowed(_ event: Event?, settings: SweepSettings) -> Event? {
        settings.allows(.menubarSwitchApps) ? event : nil
    }
}
