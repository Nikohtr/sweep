import CoreGraphics

/// Identifies a set of connected displays by their global frames (order does not matter).
public struct DisplaySignature: Hashable, Sendable {
    public let frames: [CGRect]

    public init(screens: [CGRect]) {
        frames = screens.sorted { ($0.minX, $0.minY, $0.width, $0.height) < ($1.minX, $1.minY, $1.width, $1.height) }
    }

    public static func == (a: DisplaySignature, b: DisplaySignature) -> Bool { a.frames == b.frames }

    public func hash(into h: inout Hasher) {
        for f in frames {
            h.combine(f.minX); h.combine(f.minY); h.combine(f.width); h.combine(f.height)
        }
    }
}

/// Window frames per display set, so a layout can come back after a display is replugged.
/// The restore waits for the "Restore windows after" time (Settings › Layout › Displays).
public struct LayoutMemory<Key: Hashable> {
    private var layouts: [DisplaySignature: [Key: CGRect]] = [:]

    public init() {}

    /// Stores the current layout for this display set, replacing the older one.
    public mutating func record(signature: DisplaySignature, frames: [Key: CGRect]) {
        layouts[signature] = frames
    }

    public func saved(for signature: DisplaySignature) -> [Key: CGRect]? { layouts[signature] }

    /// Frames to apply: saved frames of windows that still exist and are somewhere else now.
    /// Empty when the display set is unknown or the timeout is 0 (off).
    public func restorePlan(signature: DisplaySignature, current: [Key: CGRect],
                            timeoutSeconds: Int) -> [Key: CGRect] {
        guard timeoutSeconds > 0, let saved = layouts[signature] else { return [:] }
        return saved.filter { key, frame in current[key].map { $0 != frame } ?? false }
    }

    /// Seconds to wait after a display change before restoring; nil when the feature is off.
    public static func restoreDelay(settings: SweepSettings) -> Double? {
        settings.externalDisplayTimeout > 0 ? Double(settings.externalDisplayTimeout) : nil
    }
}
