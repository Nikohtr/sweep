import CoreGraphics

/// Resize adjacent windows (Snapping tab): when the user drags the edge between two snapped windows,
/// the neighbour follows so the windows stay side by side (any grid gap is kept).
public enum AdjacentResize {
    /// Edges closer than this count as shared.
    public static let tolerance: CGFloat = 2
    /// A neighbour is never made narrower or lower than this.
    public static let minimumSize: CGFloat = 100

    /// - Parameters:
    ///   - snapped: each snapped window's frame right after its snap.
    ///   - current: the same windows now.
    /// - Returns: new frames for the neighbours that must follow.
    public static func adjust<Key: Hashable>(snapped: [Key: CGRect], current: [Key: CGRect]) -> [Key: CGRect] {
        var out: [Key: CGRect] = [:]
        for (key, old) in snapped {
            guard let now = current[key], now.size != old.size else { continue }   // moves are not resizes
            for (other, theirs) in snapped where other != key {
                var frame = out[other] ?? current[other] ?? theirs
                let rowOverlap = theirs.minY < old.maxY && theirs.maxY > old.minY
                let columnOverlap = theirs.minX < old.maxX && theirs.maxX > old.minX
                if rowOverlap, now.maxX != old.maxX, abs(theirs.minX - old.maxX) <= tolerance + gap(theirs.minX, old.maxX) {
                    let edge = min(now.maxX + (theirs.minX - old.maxX), frame.maxX - minimumSize)
                    frame = CGRect(x: edge, y: frame.minY, width: frame.maxX - edge, height: frame.height)
                } else if rowOverlap, now.minX != old.minX, abs(old.minX - theirs.maxX) <= tolerance + gap(old.minX, theirs.maxX) {
                    let edge = max(now.minX - (old.minX - theirs.maxX), frame.minX + minimumSize)
                    frame = CGRect(x: frame.minX, y: frame.minY, width: edge - frame.minX, height: frame.height)
                } else if columnOverlap, now.maxY != old.maxY, abs(theirs.minY - old.maxY) <= tolerance + gap(theirs.minY, old.maxY) {
                    let edge = min(now.maxY + (theirs.minY - old.maxY), frame.maxY - minimumSize)
                    frame = CGRect(x: frame.minX, y: edge, width: frame.width, height: frame.maxY - edge)
                } else if columnOverlap, now.minY != old.minY, abs(old.minY - theirs.maxY) <= tolerance + gap(old.minY, theirs.maxY) {
                    let edge = max(now.minY - (old.minY - theirs.maxY), frame.minY + minimumSize)
                    frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: edge - frame.minY)
                } else {
                    continue
                }
                out[other] = frame
            }
        }
        return out
    }

    /// Grid gaps up to 12 pt still count as "touching".
    private static func gap(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let d = a - b
        return d > 0 && d <= 12 ? d : 0
    }
}
