import CoreGraphics

/// Drag to unsnap (Snapping tab): dragging a snapped window by its titlebar gives back the size it had
/// before it was snapped. Holding the secondary modifier skips this.
public enum DragUnsnap {
    /// How far the mouse must move (points) before it counts as a drag.
    public static let threshold: CGFloat = 4

    public static func applies(settings: SweepSettings, held: ModifierKeys) -> Bool {
        settings.dragToUnsnap && !ModifierResolver.roles(held: held, settings: settings).contains(.secondary)
    }

    public static func dragStarted(from down: CGPoint, to now: CGPoint) -> Bool {
        abs(now.x - down.x) >= threshold || abs(now.y - down.y) >= threshold
    }

    /// The unsnapped frame: original size, same top edge, and the cursor at the same relative x,
    /// so the grabbed titlebar point stays under the cursor.
    public static func frame(originalSize: CGSize, current: CGRect, cursor: CGPoint) -> CGRect {
        let rx = current.width > 0 ? (cursor.x - current.minX) / current.width : 0.5
        let x = (cursor.x - rx * originalSize.width).rounded()
        return CGRect(x: x, y: current.minY, width: originalSize.width.rounded(), height: originalSize.height.rounded())
    }
}
