/// Families of window gestures that can be turned off one by one.
public enum GestureKind: String, Codable, CaseIterable, Sendable {
    case halves, quarters, maximize, thirds, ninths
    case close, minimize, fullscreen, center, hideApps, screens, spaces

    public static func of(_ action: WindowAction) -> GestureKind {
        switch action {
        case .snap(let target):
            switch target {
            case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return .halves
            case .topLeft, .topRight, .bottomLeft, .bottomRight: return .quarters
            case .maximize, .almostMaximize: return .maximize
            case .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds: return .thirds
            case .grid(let span): return span.rows == 2 ? .thirds : .ninths
            }
        case .close: return .close
        case .minimize: return .minimize
        case .toggleFullscreen: return .fullscreen
        case .center: return .center
        case .hideApp, .hideOtherApps: return .hideApps
        case .moveToScreen, .fullscreenOnOtherScreen, .moveToOtherScreen: return .screens
        case .moveToSpace: return .spaces
        }
    }

    /// Shown under "Snapping" in the Gestures tab.
    public static let snapping: [GestureKind] = [.halves, .quarters, .maximize, .thirds, .ninths, .center]
    /// Shown under "Windows" in the Gestures tab.
    public static let window: [GestureKind] = [.close, .minimize, .fullscreen, .hideApps, .screens, .spaces]

    public var title: String {
        switch self {
        case .halves: return "Halves (swipe left or right; up or down twice)"
        case .quarters: return "Quarters (swipe across, then up or down)"
        case .maximize: return "Fill the screen (swipe up)"
        case .thirds: return "Thirds and sixths (with the Extend key)"
        case .ninths: return "Ninths (with the Fine key)"
        case .close: return "Close (pinch in)"
        case .minimize: return "Minimize (swipe down)"
        case .fullscreen: return "Fullscreen (pinch out)"
        case .center: return "Unsnap and center (double tap)"
        case .hideApps: return "Hide apps (Action or Extend key + double tap)"
        case .screens: return "Other displays (with the Display key)"
        case .spaces: return "Other Spaces (tap and hold, then swipe)"
        }
    }
}
