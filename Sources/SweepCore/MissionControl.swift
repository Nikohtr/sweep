import CoreGraphics

/// Gestures on window thumbnails while Mission Control or App Exposé is showing.
/// Detection: the Dock app has a child element titled for the mode only while the mode is on.
public enum MissionControlState {
    /// The Dock app has a child element with one of these titles only while the mode is on.
    static let modeTitles: Set<String> = ["Mission Control", "App Expose"]

    public static func isShowing(dockChildTitles: [String?]) -> Bool {
        dockChildTitles.contains { $0.map(modeTitles.contains) ?? false }
    }
}

/// Finds the real window behind a thumbnail by its title: an exact match first, then a unique prefix match.
public enum WindowMatch {
    public static func best(title: String, candidates: [String]) -> Int? {
        guard !title.isEmpty else { return nil }
        let exact = candidates.indices.filter { candidates[$0] == title }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 { return nil }
        let prefix = candidates.indices.filter { candidates[$0].hasPrefix(title) }
        return prefix.count == 1 ? prefix[0] : nil
    }
}

public enum MissionControlActions {
    /// Seconds to wait after leaving Mission Control (Esc) before acting on the window.
    public static let leaveDelay = 0.3

    /// On lift only. A small set that makes sense on a thumbnail.
    public static func finalAction(for steps: [Primitive]) -> WindowAction? {
        switch steps.filter({ $0 != .pause }) {
        case [.pinchIn]: return .close
        case [.swipe(.down)]: return .minimize
        case [.swipe(.left)]: return .snap(.leftHalf)
        case [.swipe(.right)]: return .snap(.rightHalf)
        case [.swipe(.up)]: return .snap(.maximize)
        default: return nil
        }
    }
}

/// The Spaces bar along the top of the screen in Mission Control.
public enum MissionControlSpaces {
    /// Depth of the Spaces bar band from the screen top.
    public static let barHeight: CGFloat = 120

    public static func isInSpacesBar(cursor: CGPoint, screenFrame: CGRect) -> Bool {
        cursor.x >= screenFrame.minX && cursor.x < screenFrame.maxX
            && cursor.y >= screenFrame.minY && cursor.y <= screenFrame.minY + barHeight
    }

    /// One swipe = move the Space to the next screen that way.
    public static func direction(for steps: [Primitive]) -> Direction? {
        let moves = steps.filter { $0 != .pause }
        if moves.count == 1, case .swipe(let d) = moves[0] { return d }
        return nil
    }
}

/// Drags a Space thumbnail to another screen's Spaces bar with synthetic mouse events (public events only).
public enum SpaceDragPlan {
    public static func target(screen: CGRect) -> CGPoint {
        CGPoint(x: screen.midX, y: screen.minY + 60)
    }

    public static func steps(from: CGPoint, to: CGPoint, cursor: CGPoint) -> [SpaceMovePlan.Step] {
        let drags = (1...6).map { i -> SpaceMovePlan.Step in
            let t = CGFloat(i) / 6
            return .drag(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
        }
        return [.mouseDown(from)] + drags + [.wait(0.3), .mouseUp(to), .warp(cursor)]
    }
}
