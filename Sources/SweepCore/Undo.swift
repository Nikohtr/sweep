import CoreGraphics

/// The frames windows had before Sweep moved, resized or snapped them, newest last.
public struct UndoStack<Key: Hashable> {
    public static var capacity: Int { 10 }

    public struct Entry {
        public let key: Key
        public let frame: CGRect
        let group: Int
    }

    private var entries: [Entry] = []

    public init() {}

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    /// Records `frame` (the window's frame before the change). `group` names one gesture or key press:
    /// a second change to the same window in the same group is not recorded, so undo goes back to the
    /// frame from before the whole gesture.
    public mutating func record(_ key: Key, frame: CGRect, group: Int) {
        if entries.contains(where: { $0.key == key && $0.group == group }) { return }
        entries.append(Entry(key: key, frame: frame, group: group))
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
    }

    /// The newest entry whose window still exists; entries of closed windows are dropped on the way.
    public mutating func popAlive(_ isAlive: (Key) -> Bool) -> Entry? {
        while let last = entries.popLast() {
            if isAlive(last.key) { return last }
        }
        return nil
    }
}

public enum UndoPolicy {
    /// Moves, resizes and snaps can be undone. Close, minimize, fullscreen, hiding and Space moves cannot:
    /// macOS has its own way back for those.
    public static func records(_ action: WindowAction) -> Bool {
        switch action {
        case .snap, .center, .moveToScreen, .moveToOtherScreen: return true
        case .close, .minimize, .toggleFullscreen, .hideApp, .hideOtherApps, .moveToSpace, .fullscreenOnOtherScreen:
            return false
        }
    }
}

extension HotkeyMap {
    /// Z (physical key position), pressed with the Anywhere key.
    public static let undoKeyCode: UInt16 = 6

    /// The key codes to register for these settings: direction and center keys when keyboard snapping is on,
    /// and the undo key when its hotkey is on.
    public static func activeKeyCodes(settings: SweepSettings) -> [UInt16] {
        (settings.arrowHotkeys ? registeredKeyCodes(settings: settings) : [])
            + (settings.undoHotkey ? [undoKeyCode] : [])
    }
}
