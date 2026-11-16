import CoreGraphics

/// Screen neighbours by physical layout, and moving a frame between screens.
/// All rects are global, top-left origin.
public enum ScreenLayout {
    /// The nearest screen in `direction` from screen `index`. Screens that share rows (for left/right)
    /// or columns (for up/down) with the current one win over diagonal ones; then the closest wins.
    public static func neighbor(of index: Int, direction: Direction, screens: [CGRect]) -> Int? {
        guard screens.indices.contains(index) else { return nil }
        let cur = screens[index]
        var best: (index: Int, overlaps: Bool, distance: CGFloat)?
        for (i, s) in screens.enumerated() where i != index {
            let inDirection: Bool
            let distance: CGFloat
            let overlaps: Bool
            switch direction {
            case .right:
                inDirection = s.midX > cur.midX && s.minX >= cur.maxX - 1
                distance = s.minX - cur.maxX
                overlaps = s.minY < cur.maxY && s.maxY > cur.minY
            case .left:
                inDirection = s.midX < cur.midX && s.maxX <= cur.minX + 1
                distance = cur.minX - s.maxX
                overlaps = s.minY < cur.maxY && s.maxY > cur.minY
            case .down:
                inDirection = s.midY > cur.midY && s.minY >= cur.maxY - 1
                distance = s.minY - cur.maxY
                overlaps = s.minX < cur.maxX && s.maxX > cur.minX
            case .up:
                inDirection = s.midY < cur.midY && s.maxY <= cur.minY + 1
                distance = cur.minY - s.maxY
                overlaps = s.minX < cur.maxX && s.maxX > cur.minX
            }
            guard inDirection else { continue }
            if let b = best {
                if b.overlaps && !overlaps { continue }
                if b.overlaps == overlaps && b.distance <= distance { continue }
            }
            best = (i, overlaps, distance)
        }
        return best?.index
    }

    /// The "other" screen for two-screen actions: the next index, wrapping. Nil with fewer than two screens.
    public static func otherScreen(of index: Int, count: Int) -> Int? {
        guard count >= 2, (0..<count).contains(index) else { return nil }
        return (index + 1) % count
    }

    /// Moves `frame` from one visible frame to another, keeping its relative position and size.
    public static func move(frame: CGRect, from: CGRect, to: CGRect) -> CGRect {
        let sx = to.width / from.width
        let sy = to.height / from.height
        let w = min((frame.width * sx).rounded(), to.width)
        let h = min((frame.height * sy).rounded(), to.height)
        var x = (to.minX + (frame.minX - from.minX) * sx).rounded()
        var y = (to.minY + (frame.minY - from.minY) * sy).rounded()
        x = min(max(x, to.minX), to.maxX - w)
        y = min(max(y, to.minY), to.maxY - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
