/// Every user setting, with defaults and ranges.
///
/// Each number has a range (see the `…Range` constants); `clamped()` keeps values inside it.
public struct SweepSettings: Codable, Equatable, Sendable {
    public enum ArrowKeys: String, Codable, Sendable, CaseIterable { case arrows, wasd, dvorak }
    public enum CenterKey: String, Codable, Sendable, CaseIterable { case escape, backspace, returnKey }

    // General
    public var gesturesEnabled = true           // menu bar "Enable Gestures"
    public var launchAtLogin = false
    public var showInMenuBar = true
    public var hapticFeedback = true
    public var sensitivity = 3                  // 1...4
    public var tapHold = true
    public var cancelTimeoutMs = 800            // 400...2000
    public var tooltipsEnabled = true
    public var tooltipSize = 5                  // 3...7
    public var hideCursor = false
    public var liveTooltips = true
    /// The welcome tutorial was finished once.
    public var tutorialSeen = false
    /// Gesture families that are turned off. Default: all on.
    public var disabledGestures: [GestureKind] = []

    // Windows
    public var missionControlGestures = true
    public var screensChainGesture = false
    public var screensMoveCursor = false
    /// Kinds of apps where tab gestures are off (gestures on their tabs act on the window). Default: all on.
    public var disabledTabApps: [TabApp] = []

    // Snapping
    public var nativeTiling = false
    public var stageManagerOffset = 190         // 0...240
    public var gridSpacing = 0                  // -1...12
    public var gridIncludesScreenEdges = false
    public var dragToUnsnap = true
    public var activateAfterSnap = true
    public var moveCursorAfterSnap = false
    public var resizeAdjacent = true
    public var swipeUpFillsAlmost = false       // Which "swipe up once" gesture is on

    /// Dock and menu bar gestures that are turned off. Missing in old stored settings = all on.
    public var disabledDockMenuGestures: [DockMenuGestureKind] = []

    // Apps
    public var appMenuGestures = true
    /// Bundle IDs of apps where Sweep takes no gestures.
    public var ignoredApps: [String] = []

    // Advanced
    public var activeEventListener = false
    public var disableMagicMouse = false
    public var externalDisplayTimeout = 4       // 0...20 seconds, 0 = off
    public var requireSuperModifier = false
    public var arrowHotkeys = false
    /// Anywhere key + Z undoes the last window move. Off by default.
    public var undoHotkey = false
    public var arrowKeys = ArrowKeys.arrows
    public var centerKey = CenterKey.escape

    // Modifiers (defaults: SweepSettings.defaultModifiers)
    public var generalModifier: ModifierKeys = [.control]
    public var screenModifier: ModifierKeys = [.option]
    public var secondaryModifier: ModifierKeys = [.shift]
    public var tertiaryModifier: ModifierKeys = [.control, .shift]
    public var superModifier: ModifierKeys = [.command]

    public static let sensitivityRange = 1...4
    public static let cancelTimeoutRange = 400...2000
    public static let tooltipSizeRange = 3...7
    public static let gridSpacingRange = -1...12
    public static let stageManagerOffsetRange = 0...240
    public static let externalDisplayTimeoutRange = 0...20

    public init() {}

    /// A copy with every number forced into its range.
    public func clamped() -> SweepSettings {
        var s = self
        s.sensitivity = Self.clamp(sensitivity, Self.sensitivityRange)
        s.cancelTimeoutMs = Self.clamp(cancelTimeoutMs, Self.cancelTimeoutRange)
        s.tooltipSize = Self.clamp(tooltipSize, Self.tooltipSizeRange)
        s.gridSpacing = Self.clamp(gridSpacing, Self.gridSpacingRange)
        s.stageManagerOffset = Self.clamp(stageManagerOffset, Self.stageManagerOffsetRange)
        s.externalDisplayTimeout = Self.clamp(externalDisplayTimeout, Self.externalDisplayTimeoutRange)
        return s
    }

    public var recognizerConfig: RecognizerConfig {
        RecognizerConfig(sensitivity: sensitivity, cancelTimeoutMs: cancelTimeoutMs, tapHoldEnabled: tapHold)
    }

    private static func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int { min(max(v, r.lowerBound), r.upperBound) }

    /// Missing keys keep their defaults, so old saved settings still load after an update.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SweepSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        gesturesEnabled = try v(.gesturesEnabled, d.gesturesEnabled)
        launchAtLogin = try v(.launchAtLogin, d.launchAtLogin)
        showInMenuBar = try v(.showInMenuBar, d.showInMenuBar)
        hapticFeedback = try v(.hapticFeedback, d.hapticFeedback)
        sensitivity = try v(.sensitivity, d.sensitivity)
        tapHold = try v(.tapHold, d.tapHold)
        cancelTimeoutMs = try v(.cancelTimeoutMs, d.cancelTimeoutMs)
        tooltipsEnabled = try v(.tooltipsEnabled, d.tooltipsEnabled)
        tooltipSize = try v(.tooltipSize, d.tooltipSize)
        hideCursor = try v(.hideCursor, d.hideCursor)
        liveTooltips = try v(.liveTooltips, d.liveTooltips)
        tutorialSeen = try v(.tutorialSeen, d.tutorialSeen)
        disabledGestures = try v(.disabledGestures, d.disabledGestures)
        missionControlGestures = try v(.missionControlGestures, d.missionControlGestures)
        screensChainGesture = try v(.screensChainGesture, d.screensChainGesture)
        screensMoveCursor = try v(.screensMoveCursor, d.screensMoveCursor)
        disabledTabApps = try v(.disabledTabApps, d.disabledTabApps)
        nativeTiling = try v(.nativeTiling, d.nativeTiling)
        stageManagerOffset = try v(.stageManagerOffset, d.stageManagerOffset)
        gridSpacing = try v(.gridSpacing, d.gridSpacing)
        gridIncludesScreenEdges = try v(.gridIncludesScreenEdges, d.gridIncludesScreenEdges)
        dragToUnsnap = try v(.dragToUnsnap, d.dragToUnsnap)
        activateAfterSnap = try v(.activateAfterSnap, d.activateAfterSnap)
        moveCursorAfterSnap = try v(.moveCursorAfterSnap, d.moveCursorAfterSnap)
        resizeAdjacent = try v(.resizeAdjacent, d.resizeAdjacent)
        swipeUpFillsAlmost = try v(.swipeUpFillsAlmost, d.swipeUpFillsAlmost)
        // Unknown names (from a newer version) are skipped instead of failing the whole decode.
        disabledDockMenuGestures = (try? c.decodeIfPresent([String].self, forKey: .disabledDockMenuGestures))?
            .flatMap { $0.compactMap(DockMenuGestureKind.init(rawValue:)) } ?? d.disabledDockMenuGestures
        appMenuGestures = try v(.appMenuGestures, d.appMenuGestures)
        ignoredApps = try v(.ignoredApps, d.ignoredApps)
        activeEventListener = try v(.activeEventListener, d.activeEventListener)
        disableMagicMouse = try v(.disableMagicMouse, d.disableMagicMouse)
        externalDisplayTimeout = try v(.externalDisplayTimeout, d.externalDisplayTimeout)
        requireSuperModifier = try v(.requireSuperModifier, d.requireSuperModifier)
        arrowHotkeys = try v(.arrowHotkeys, d.arrowHotkeys)
        undoHotkey = try v(.undoHotkey, d.undoHotkey)
        arrowKeys = try v(.arrowKeys, d.arrowKeys)
        centerKey = try v(.centerKey, d.centerKey)
        generalModifier = try v(.generalModifier, d.generalModifier)
        screenModifier = try v(.screenModifier, d.screenModifier)
        secondaryModifier = try v(.secondaryModifier, d.secondaryModifier)
        tertiaryModifier = try v(.tertiaryModifier, d.tertiaryModifier)
        superModifier = try v(.superModifier, d.superModifier)
        self = clamped()
    }
}
