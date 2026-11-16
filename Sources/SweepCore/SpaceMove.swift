import CoreGraphics

/// How the app moves a window to the next Space with public APIs only: hold the window
/// by its titlebar with a synthetic mouse press, switch Spaces with the Mission Control shortcut
/// (⌃← / ⌃→), then let go. macOS carries a held window along to the new Space.
public enum SpaceMovePlan {
    public enum Step: Sendable, Equatable {
        case mouseDown(CGPoint)
        case drag(CGPoint)
        case mouseUp(CGPoint)
        case key(KeyChord)
        case wait(Double)
        case warp(CGPoint)
    }

    /// A point on the titlebar to the right of the window buttons (about 70 pt wide), or the
    /// middle of a narrow window. Top-left global coordinates.
    public static func grabPoint(frame: CGRect) -> CGPoint {
        CGPoint(x: min(frame.minX + 100, frame.midX), y: frame.minY + 12)
    }

    /// Empty for up/down: Spaces sit side by side.
    public static func steps(grab: CGPoint, direction: Direction, cursor: CGPoint) -> [Step] {
        let keyCode: UInt16
        switch direction {
        case .left: keyCode = 123
        case .right: keyCode = 124
        case .up, .down: return []
        }
        return [.mouseDown(grab), .drag(grab), .wait(0.1),
                .key(KeyChord(keyCode: keyCode, modifiers: [.control])), .wait(0.4),
                .mouseUp(grab), .warp(cursor)]
    }
}
