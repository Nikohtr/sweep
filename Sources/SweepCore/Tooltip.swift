import CoreGraphics

/// What the overlay shows while a gesture is in progress.
public struct Tooltip: Sendable, Equatable {
    /// Where the window will go (global, top-left), or nil for a label-only tooltip.
    public let preview: CGRect?
    public let label: String
    public let fontSize: CGFloat
}

public enum TooltipPlan {
    /// Nil when tooltips are off or the gesture has no action yet.
    public static func make(action: WindowAction?, windowFrame: CGRect, visible: CGRect, settings: SweepSettings,
                            stageManagerOn: Bool = false) -> Tooltip? {
        guard settings.tooltipsEnabled, let action else { return nil }
        var preview: CGRect? = nil
        if settings.liveTooltips {
            if case .snap(let target) = action {
                preview = SnapLayout.frame(for: target, in: visible, settings: settings, stageManagerOn: stageManagerOn)
            } else {
                preview = windowFrame
            }
        }
        // 3 pt of text per slider step (3…7 → 9…21 pt).
        return Tooltip(preview: preview, label: label(for: action), fontSize: CGFloat(settings.tooltipSize * 3))
    }

    public static func label(for action: WindowAction) -> String {
        switch action {
        case .snap(let target):
            switch target {
            case .leftHalf: return "Left half"
            case .rightHalf: return "Right half"
            case .topHalf: return "Top half"
            case .bottomHalf: return "Bottom half"
            case .maximize: return "Fill the screen"
            case .almostMaximize: return "Almost fill the screen"
            case .topLeft: return "Top left quarter"
            case .topRight: return "Top right quarter"
            case .bottomLeft: return "Bottom left quarter"
            case .bottomRight: return "Bottom right quarter"
            case .leftThird: return "Left third"
            case .centerThird: return "Center third"
            case .rightThird: return "Right third"
            case .leftTwoThirds: return "Left two thirds"
            case .rightTwoThirds: return "Right two thirds"
            case .grid(let span):
                return "\(span.x.count * span.y.count)/\(span.columns * span.rows) of the screen"
            }
        case .minimize: return "Minimize"
        case .close: return "Close"
        case .toggleFullscreen: return "Fullscreen"
        case .center: return "Unsnap and center"
        case .hideApp: return "Hide app"
        case .hideOtherApps: return "Hide other apps"
        case .moveToScreen: return "Move to next screen"
        case .fullscreenOnOtherScreen: return "Fullscreen on the other screen"
        case .moveToOtherScreen: return "Move to the other screen"
        case .moveToSpace(let d): return d == .left ? "Move to the Space on the left" : "Move to the Space on the right"
        }
    }
}
