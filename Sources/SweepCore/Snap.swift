import CoreGraphics

/// A block of cells in a columns × rows grid. `x` and `y` are cell index ranges.
public struct GridSpan: Sendable, Hashable {
    public var columns: Int
    public var rows: Int
    public var x: Range<Int>
    public var y: Range<Int>

    public init(columns: Int, rows: Int, x: Range<Int>, y: Range<Int>) {
        self.columns = columns
        self.rows = rows
        self.x = x
        self.y = y
    }
}

/// A place a window can snap to.
public enum SnapTarget: Sendable, Equatable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    /// Fill the whole visible frame.
    case maximize
    /// Fill almost all of it: 5 % margin per side.
    case almostMaximize
    case topLeft, topRight, bottomLeft, bottomRight
    /// 3×2 grid columns (secondary modifier).
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    /// Any block of a grid (sixths, ninths …).
    case grid(GridSpan)
}

/// What a gesture asks the app to do with the target window.
public enum WindowAction: Sendable, Equatable {
    case snap(SnapTarget)
    case minimize
    case close
    case toggleFullscreen
    /// Unsnap (restore the size from before the first snap) and center on the screen.
    case center
    /// Hide the window's app (general modifier + double tap).
    case hideApp
    /// Hide every other app (secondary modifier + double tap).
    case hideOtherApps
    /// Move to the next screen in that direction (screen modifier).
    case moveToScreen(Direction)
    /// Fullscreen on the other screen (two screens): screen modifier + pinch out, or pinch out twice.
    case fullscreenOnOtherScreen
    /// The move part of `fullscreenOnOtherScreen`: to the next screen, same relative frame.
    case moveToOtherScreen
    /// Move to the Space on the left or right (tap-and-hold + swipe, or general modifier + swipe).
    case moveToSpace(Direction)
}

/// Frame math for snapping. All rects are global, top-left origin.
public enum SnapLayout {
    public static func frame(for target: SnapTarget, in visible: CGRect) -> CGRect {
        // Split on a whole point so neighbours share one edge with no gap.
        let leftWidth = (visible.width / 2).rounded(.down)
        let topHeight = (visible.height / 2).rounded(.down)
        let third = (visible.width / 3).rounded(.down)
        let twoThirds = (visible.width * 2 / 3).rounded(.down)
        func column(_ from: CGFloat, _ to: CGFloat) -> CGRect {
            CGRect(x: visible.minX + from, y: visible.minY, width: to - from, height: visible.height)
        }
        switch target {
        case .grid(let g):
            // Edge i of n parts sits at floor(length · i / n), so neighbours share edges exactly.
            func edge(_ i: Int, _ n: Int, _ length: CGFloat) -> CGFloat { (length * CGFloat(i) / CGFloat(n)).rounded(.down) }
            let x0 = edge(g.x.lowerBound, g.columns, visible.width), x1 = edge(g.x.upperBound, g.columns, visible.width)
            let y0 = edge(g.y.lowerBound, g.rows, visible.height), y1 = edge(g.y.upperBound, g.rows, visible.height)
            return CGRect(x: visible.minX + x0, y: visible.minY + y0, width: x1 - x0, height: y1 - y0)
        case .leftThird: return column(0, third)
        case .centerThird: return column(third, twoThirds)
        case .rightThird: return column(twoThirds, visible.width)
        case .leftTwoThirds: return column(0, twoThirds)
        case .rightTwoThirds: return column(third, visible.width)
        case .maximize:
            return visible
        case .almostMaximize:
            let dx = (visible.width * 0.05).rounded(), dy = (visible.height * 0.05).rounded()
            return visible.insetBy(dx: dx, dy: dy)
        case .topHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: topHeight)
        case .bottomHalf:
            return CGRect(x: visible.minX, y: visible.minY + topHeight,
                          width: visible.width, height: visible.height - topHeight)
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let left = target == .topLeft || target == .bottomLeft
            let top = target == .topLeft || target == .topRight
            return CGRect(x: left ? visible.minX : visible.minX + leftWidth,
                          y: top ? visible.minY : visible.minY + topHeight,
                          width: left ? leftWidth : visible.width - leftWidth,
                          height: top ? topHeight : visible.height - topHeight)
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: leftWidth, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.minX + leftWidth, y: visible.minY,
                          width: visible.width - leftWidth, height: visible.height)
        }
    }

    /// Like `frame(for:in:)` with gaps.
    /// - `spacing` points between neighbouring cells (−1 makes neighbours overlap by 1 pt).
    /// - With `screenEdges`, outer sides are also inset by `spacing` (never by a negative amount).
    /// All results stay on whole points; an odd gap is split floor/ceil so the total is exact.
    public static func frame(for target: SnapTarget, in visible: CGRect, spacing: CGFloat,
                             screenEdges: Bool) -> CGRect {
        let cell = frame(for: target, in: visible)
        if target == .almostMaximize { return cell }   // already has its own margin
        let edge = screenEdges ? max(spacing, 0) : 0
        let before = (spacing / 2).rounded(.up)     // gap on a cell's left/top inner side
        let after = (spacing / 2).rounded(.down)    // gap on a cell's right/bottom inner side
        let minX = cell.minX + (cell.minX == visible.minX ? edge : before)
        let minY = cell.minY + (cell.minY == visible.minY ? edge : before)
        let maxX = cell.maxX - (cell.maxX == visible.maxX ? edge : after)
        let maxY = cell.maxY - (cell.maxY == visible.maxY ? edge : after)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func frame(for target: SnapTarget, in visible: CGRect, settings: SweepSettings,
                             stageManagerOn: Bool = false) -> CGRect {
        let usable = usableFrame(visible: visible, stageManagerOn: stageManagerOn,
                                 offset: CGFloat(settings.stageManagerOffset))
        return frame(for: target, in: usable, spacing: CGFloat(settings.gridSpacing),
                     screenEdges: settings.gridIncludesScreenEdges)
    }

    /// The part of the visible frame that snapping may use. With Stage Manager on, the left
    /// `offset` points stay free for its strip of recent apps. At least half the width is kept.
    public static func usableFrame(visible: CGRect, stageManagerOn: Bool, offset: CGFloat) -> CGRect {
        guard stageManagerOn, offset > 0 else { return visible }
        let cut = min(offset, (visible.width / 2).rounded(.down))
        return CGRect(x: visible.minX + cut, y: visible.minY, width: visible.width - cut, height: visible.height)
    }

    /// A frame of `size` centered in `visible`, on whole points, never larger than `visible`.
    public static func centered(size: CGSize, in visible: CGRect) -> CGRect {
        let w = min(size.width.rounded(), visible.width)
        let h = min(size.height.rounded(), visible.height)
        return CGRect(x: (visible.minX + (visible.width - w) / 2).rounded(.down),
                      y: (visible.minY + (visible.height - h) / 2).rounded(.down), width: w, height: h)
    }

    /// Index of the screen that shows most of the window, or nil if it is on none.
    public static func screenIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (i, s) in screens.enumerated() {
            let r = s.intersection(window)
            guard !r.isNull else { continue }
            let area = r.width * r.height
            if area > 0, area > (best?.area ?? 0) { best = (i, area) }
        }
        return best?.index
    }
}

/// Maps gesture steps made on a titlebar or toolbar to a window action.
/// Rules: a horizontal swipe snaps to the left or right half; one swipe up
/// fills the desktop; a vertical double swipe (with a short pause) snaps to the top or bottom half.
/// One horizontal and one vertical swipe, in either order, snaps to a quarter.
/// A single swipe down minimizes and a single pinch in closes, but only when the gesture ends
/// (see `finalAction`). Pinch out, or hold then swipe up, toggles fullscreen on lift.
public enum TitlebarActions {
    /// Live action with roles and user settings (swipe-up variant, screen chain).
    public static func action(for steps: [Primitive], roles: Set<ModifierRole>, settings: SweepSettings) -> WindowAction? {
        if roles.contains(.screen), let chained = screenChain(steps, settings) { return adjust(action(for: chained), settings) }
        return adjust(action(for: steps, roles: roles), settings)
    }

    /// Final action with roles and user settings.
    public static func finalAction(for steps: [Primitive], roles: Set<ModifierRole>, settings: SweepSettings) -> WindowAction? {
        if roles.contains(.screen), let chained = screenChain(steps, settings) { return adjust(finalAction(for: chained), settings) }
        return adjust(finalAction(for: steps, roles: roles), settings)
    }

    /// Screens "chain gesture": after the first swipe moved the window to another screen, the rest of the
    /// gesture is a plain titlebar gesture on it. Nil when chaining is off or nothing follows the move.
    static func screenChain(_ steps: [Primitive], _ settings: SweepSettings) -> [Primitive]? {
        guard settings.screensChainGesture,
              let first = steps.firstIndex(where: { if case .swipe = $0 { return true } else { return false } })
        else { return nil }
        let rest = Array(steps[(first + 1)...])
        return rest.contains(where: { $0 != .pause }) ? rest : nil
    }

    private static func adjust(_ a: WindowAction?, _ settings: SweepSettings) -> WindowAction? {
        var a = a
        if a == .snap(.maximize), settings.swipeUpFillsAlmost { a = .snap(.almostMaximize) }
        if let action = a, settings.disabledGestures.contains(GestureKind.of(action)) { return nil }
        return a
    }

    /// Like `finalAction(for:)`, with modifier roles. The screen role turns one swipe into a screen move.
    public static func finalAction(for steps: [Primitive], roles: Set<ModifierRole>) -> WindowAction? {
        if roles.contains(.screen) {
            if steps.filter({ $0 != .pause }) == [.pinchOut] { return .fullscreenOnOtherScreen }
            return screenAction(steps)
        }
        if roles.contains(.tertiary) { return ninthsAction(steps) }
        let isDoubleTap = steps.filter { $0 != .pause } == [.tap]
        // Double tap with the general modifier hides the app; the secondary modifier hides the others.
        if roles.contains(.general), isDoubleTap { return .hideApp }
        if roles.contains(.secondary), isDoubleTap { return .hideOtherApps }
        if roles.contains(.secondary) { return thirdsAction(steps) }
        // The general modifier + swipe down closes the window (on lift).
        if roles.contains(.general), let close = generalDownAction(steps) { return close }
        if roles.contains(.general), let space = generalSpaceAction(steps) { return space }
        return finalAction(for: steps)
    }

    /// Like `action(for:)`, with modifier roles.
    public static func action(for steps: [Primitive], roles: Set<ModifierRole>) -> WindowAction? {
        if roles.contains(.screen) { return screenAction(steps) }
        if roles.contains(.tertiary) { return ninthsAction(steps) }
        // Hiding happens on lift only (see finalAction); never center live under these modifiers.
        if roles.contains(.general), steps.filter({ $0 != .pause }) == [.tap] { return nil }
        if roles.contains(.secondary) { return thirdsAction(steps) }
        if roles.contains(.general), generalDownAction(steps) != nil { return nil }   // close on lift only
        if roles.contains(.general), generalSpaceAction(steps) != nil { return nil }  // Space move on lift only
        return action(for: steps)
    }

    /// General modifier with only downward swipes: one closes; more do nothing (never bottom half).
    /// Nil when the gesture is something else, so other rules apply. Outer optional = "handled".
    private static func generalDownAction(_ steps: [Primitive]) -> WindowAction?? {
        let moves = steps.filter { $0 != .pause }
        guard !moves.isEmpty, moves.allSatisfy({ $0 == .swipe(.down) }) else { return nil }
        return .some(moves.count == 1 ? .close : nil)
    }

    /// General modifier with only horizontal swipes: one moves the window to that Space; more do nothing.
    private static func generalSpaceAction(_ steps: [Primitive]) -> WindowAction?? {
        let moves = steps.filter { $0 != .pause }
        guard !moves.isEmpty, moves.allSatisfy({ $0 == .swipe(.left) || $0 == .swipe(.right) }) else { return nil }
        guard moves.count == 1, case .swipe(let d) = moves[0] else { return .some(nil) }
        return .some(.moveToSpace(d))
    }

    /// Secondary modifier: a horizontal swipe gives a third; repeating it (after a pause) toggles
    /// two-thirds; a hold gives the center third.
    private static func thirdsAction(_ steps: [Primitive]) -> WindowAction? {
        let moves = steps.filter { $0 != .pause }
        if moves == [.hold] { return .snap(.centerThird) }
        let hold = moves.first == .hold
        var horizontal: [Direction] = []
        var vertical: [Direction] = []
        for move in moves.dropFirst(hold ? 1 : 0) {
            guard case .swipe(let d) = move else { return nil }
            if d == .left || d == .right { horizontal.append(d) } else { vertical.append(d) }
        }
        // Column block from the horizontal run (odd = third, even = two-thirds), or the center for a hold.
        let columns: Range<Int>?
        if let last = horizontal.last {
            let odd = horizontal.reversed().prefix { $0 == last }.count % 2 == 1
            columns = last == .left ? (odd ? 0..<1 : 0..<2) : (odd ? 2..<3 : 1..<3)
        } else {
            columns = hold ? 1..<2 : nil
        }
        guard let columns else { return nil }
        // Sixths: a vertical swipe picks the upper or lower half of that column block (3×2 grid).
        if let v = vertical.last {
            return .snap(.grid(GridSpan(columns: 3, rows: 2, x: columns, y: v == .up ? 0..<1 : 1..<2)))
        }
        switch columns {
        case 0..<1: return .snap(.leftThird)
        case 0..<2: return .snap(.leftTwoThirds)
        case 2..<3: return .snap(.rightThird)
        case 1..<3: return .snap(.rightTwoThirds)
        default: return .snap(.centerThird)
        }
    }

    /// Tertiary modifier: a 3×3 grid. On each axis the last swipe picks the edge column/row and an even
    /// run of it widens to two; no swipe on an axis (or a hold) means the center. Gives 1/9, 2/9, 4/9.
    private static func ninthsAction(_ steps: [Primitive]) -> WindowAction? {
        let moves = steps.filter { $0 != .pause }
        let hold = moves.first == .hold
        var horizontal: [Direction] = []
        var vertical: [Direction] = []
        for move in moves.dropFirst(hold ? 1 : 0) {
            guard case .swipe(let d) = move else { return nil }
            if d == .left || d == .right { horizontal.append(d) } else { vertical.append(d) }
        }
        guard hold || !horizontal.isEmpty || !vertical.isEmpty else { return nil }
        func span(_ dirs: [Direction], low: Direction) -> Range<Int> {
            guard let last = dirs.last else { return 1..<2 }
            let odd = dirs.reversed().prefix { $0 == last }.count % 2 == 1
            return last == low ? (odd ? 0..<1 : 0..<2) : (odd ? 2..<3 : 1..<3)
        }
        return .snap(.grid(GridSpan(columns: 3, rows: 3, x: span(horizontal, low: .left), y: span(vertical, low: .up))))
    }

    private static func screenAction(_ steps: [Primitive]) -> WindowAction? {
        let moves = steps.filter { $0 != .pause }
        if moves.count == 1, case .swipe(let d) = moves[0] { return .moveToScreen(d) }
        return nil
    }

    /// The action to apply when the fingers lift. Adds actions that must not run live:
    /// a single swipe down could still become a double swipe (bottom half).
    public static func finalAction(for steps: [Primitive]) -> WindowAction? {
        switch steps.filter({ $0 != .pause }) {
        case [.swipe(.down)], [.hold, .swipe(.down)]: return .minimize
        case [.pinchIn]: return .close
        case [.pinchOut], [.hold, .swipe(.up)]: return .toggleFullscreen
        case [.pinchOut, .pinchOut]: return .fullscreenOnOtherScreen
        case [.hold, .swipe(.left)]: return .moveToSpace(.left)
        case [.hold, .swipe(.right)]: return .moveToSpace(.right)
        default: return action(for: steps)
        }
    }

    /// The action to apply live, while the fingers are still down.
    public static func action(for steps: [Primitive]) -> WindowAction? {
        let moves = steps.filter { $0 != .pause }
        guard !moves.isEmpty else { return nil }
        if moves == [.tap] { return .center }   // double tap: unsnap / center
        var dirs: [Direction] = []
        for move in moves {
            guard case .swipe(let d) = move else { return nil }
            dirs.append(d)
        }
        let horizontal = dirs.last { $0 == .left || $0 == .right }
        let vertical = dirs.last { $0 == .up || $0 == .down }
        switch (horizontal, vertical) {
        case (let h?, nil):
            return h == .left ? .snap(.leftHalf) : .snap(.rightHalf)
        case (let h?, let v?):
            switch (h, v) {
            case (.left, .up): return .snap(.topLeft)
            case (.right, .up): return .snap(.topRight)
            case (.left, _): return .snap(.bottomLeft)
            default: return .snap(.bottomRight)
            }
        default:
            break
        }
        switch dirs {
        case [.up]: return .snap(.maximize)
        case [.up, .up]: return .snap(.topHalf)
        case [.down, .down]: return .snap(.bottomHalf)
        default: return nil
        }
    }
}

/// Turns one action into the steps the app must run. macOS cannot minimize a fullscreen
/// window, so that case leaves fullscreen first and waits for the animation.
public enum ActionPlan {
    public enum Step: Sendable, Equatable {
        case perform(WindowAction)
        case wait(Double)
    }

    /// Seconds for the leave-fullscreen animation.
    public static let fullscreenExitDelay = 0.8

    /// Seconds between the screen move and entering fullscreen, so fullscreen opens on the new screen.
    public static let screenMoveDelay = 0.3

    public static func steps(for action: WindowAction, isFullscreen: Bool, hasOtherScreen: Bool = true) -> [Step] {
        if action == .fullscreenOnOtherScreen {
            guard hasOtherScreen else { return [.perform(.toggleFullscreen)] }
            let move: [Step] = [.perform(.moveToOtherScreen), .wait(screenMoveDelay), .perform(.toggleFullscreen)]
            return isFullscreen ? [.perform(.toggleFullscreen), .wait(fullscreenExitDelay)] + move : move
        }
        if action == .minimize, isFullscreen {
            return [.perform(.toggleFullscreen), .wait(fullscreenExitDelay), .perform(.minimize)]
        }
        return [.perform(action)]
    }
}

/// Remembers each window's frame from before its first snap, so a later unsnap can restore it.
public struct UnsnapMemory<Key: Hashable> {
    private var frames: [Key: CGRect] = [:]

    public init() {}

    /// Call before a snap. Only the first snap after an unsnap is remembered.
    public mutating func willSnap(_ key: Key, from frame: CGRect) {
        if frames[key] == nil { frames[key] = frame }
    }

    /// The remembered frame, removed from memory (the window is now unsnapped).
    public mutating func takeOriginal(_ key: Key) -> CGRect? {
        frames.removeValue(forKey: key)
    }

    public mutating func forget(_ key: Key) {
        frames[key] = nil
    }

    /// The remembered frame, left in memory.
    public func original(_ key: Key) -> CGRect? { frames[key] }

    /// Every window that is snapped and remembered.
    public var keys: [Key] { Array(frames.keys) }
}
