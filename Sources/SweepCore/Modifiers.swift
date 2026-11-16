/// Modifier keys a role can use.
public struct ModifierKeys: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = ModifierKeys(rawValue: 1 << 0)
    public static let option = ModifierKeys(rawValue: 1 << 1)
    public static let shift = ModifierKeys(rawValue: 1 << 2)
    public static let command = ModifierKeys(rawValue: 1 << 3)
    /// The fn / globe key. Only used for posted key chords, not for modifier roles.
    public static let function = ModifierKeys(rawValue: 1 << 4)

    /// "⌃⌥⇧⌘" in the order macOS menus use, or "none".
    public var symbols: String {
        let parts: [(ModifierKeys, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
                                              (.function, "fn")]
        let text = parts.filter { contains($0.0) }.map(\.1).joined()
        return text.isEmpty ? "none" : text
    }
}

/// What a modifier does during a gesture:
/// general functions, multi-screen actions, secondary (3×2 snapping, all windows), tertiary (3×3),
/// and super (gestures on the whole window; combines with the others).
public enum ModifierRole: String, Codable, CaseIterable, Sendable {
    case general, screen, secondary, tertiary, superKey
}

public enum ModifierResolver {
    /// Roles active for the held keys. Super is active when its keys are held; the other roles
    /// need an exact match of the remaining keys, so ⌃⇧ is tertiary and not also general.
    public static func roles(held: ModifierKeys, settings: SweepSettings) -> Set<ModifierRole> {
        // A role set to exactly the held keys wins, even when its keys include the super keys.
        let exact = Set(ModifierRole.allCases.filter {
            $0 != .superKey && !settings.keys(for: $0).isEmpty && settings.keys(for: $0) == held
        })
        if !exact.isEmpty { return exact }
        var result: Set<ModifierRole> = []
        var rest = held
        let superKeys = settings.keys(for: .superKey)
        if !superKeys.isEmpty, held.isSuperset(of: superKeys) {
            result.insert(.superKey)
            rest.subtract(superKeys)
        }
        for role in ModifierRole.allCases where role != .superKey {
            let keys = settings.keys(for: role)
            if !keys.isEmpty, keys == rest { result.insert(role) }
        }
        return result
    }
}

extension SweepSettings {
    /// The default key for each role.
    public static let defaultModifiers: [ModifierRole: ModifierKeys] = [
        .general: [.control], .screen: [.option], .secondary: [.shift],
        .tertiary: [.control, .shift], .superKey: [.command],
    ]

    public func keys(for role: ModifierRole) -> ModifierKeys {
        switch role {
        case .general: return generalModifier
        case .screen: return screenModifier
        case .secondary: return secondaryModifier
        case .tertiary: return tertiaryModifier
        case .superKey: return superModifier
        }
    }

    public mutating func setKeys(_ keys: ModifierKeys, for role: ModifierRole) {
        switch role {
        case .general: generalModifier = keys
        case .screen: screenModifier = keys
        case .secondary: secondaryModifier = keys
        case .tertiary: tertiaryModifier = keys
        case .superKey: superModifier = keys
        }
    }

    /// Every setting back to its default. The ignore list is kept unless asked,
    /// so a reset never silently drops apps the user excluded.
    public func restoredDefaults(keepingIgnoredApps: Bool = true) -> SweepSettings {
        var fresh = SweepSettings.newInstall()
        if keepingIgnoredApps { fresh.ignoredApps = ignoredApps }
        fresh.tutorialSeen = tutorialSeen   // a reset does not bring the welcome tutorial back
        return fresh
    }

    public mutating func resetModifiers() {
        for (role, keys) in Self.defaultModifiers { setKeys(keys, for: role) }
    }
}
