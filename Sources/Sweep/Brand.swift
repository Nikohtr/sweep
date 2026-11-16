import AppKit
import SwiftUI

/// Sweep's look: palette, art loading and the menu bar glyph.
@MainActor
enum Brand {
    // MARK: Palette

    static let sageDeep = NSColor(srgbRed: 0x3F / 255, green: 0x5E / 255, blue: 0x55 / 255, alpha: 1)
    static let sage = NSColor(srgbRed: 0x7F / 255, green: 0xA3 / 255, blue: 0x93 / 255, alpha: 1)
    static let sand = NSColor(srgbRed: 0xE9 / 255, green: 0xDC / 255, blue: 0xC6 / 255, alpha: 1)
    static let cream = NSColor(srgbRed: 0xF7 / 255, green: 0xF2 / 255, blue: 0xE9 / 255, alpha: 1)
    static let ink = NSColor(srgbRed: 0x23 / 255, green: 0x30 / 255, blue: 0x2B / 255, alpha: 1)

    /// UI accent: a darker sage on light backgrounds, a lighter one on dark backgrounds.
    static let nsAccent = NSColor(name: "SweepAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x8D / 255, green: 0xB3 / 255, blue: 0xA2 / 255, alpha: 1)
            : NSColor(srgbRed: 0x5E / 255, green: 0x85 / 255, blue: 0x76 / 255, alpha: 1)
    }
    static let accent = Color(nsColor: nsAccent)

    // MARK: Art

    /// `Resources/Brand` in the source tree, for `swift run` (no app bundle).
    private nonisolated static let sourceArt = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Brand")

    private static var cache: [String: NSImage] = [:]

    /// An illustration by base name, from the app bundle or the source tree. Nil if it is missing.
    static func image(_ name: String) -> NSImage? {
        if let hit = cache[name] { return hit }
        for ext in ["jpg", "png"] {
            let url = Bundle.main.url(forResource: name, withExtension: ext)
                ?? sourceArt.appendingPathComponent("\(name).\(ext)")
            if let image = NSImage(contentsOf: url) {
                cache[name] = image
                return image
            }
        }
        return nil
    }

    /// The app icon: the bundle's icon when bundled, the source PNG under `swift run`.
    static var appIcon: NSImage {
        if Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil { return NSApp.applicationIconImage }
        return image("AppIcon-1024") ?? NSApp.applicationIconImage
    }

    // MARK: Menu bar glyph

    /// The icon's motif at menu bar size: one arc that comes to rest as a tile, beside a faint empty cell.
    /// A template image, so macOS tints it for light, dark and dimmed states.
    /// `badged` adds a dot at the top left: an update waits (see `Updater`).
    static func menuBarGlyph(badged: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            // The resting tile, top right.
            NSBezierPath(roundedRect: NSRect(x: 9.5, y: 9.5, width: 7, height: 6.5), xRadius: 1.8, yRadius: 1.8).fill()
            // The sweep: from the bottom left, curving up into the tile.
            let arc = NSBezierPath()
            arc.move(to: NSPoint(x: 2.2, y: 2.2))
            arc.curve(to: NSPoint(x: 9.5, y: 12.6),
                      controlPoint1: NSPoint(x: 2.4, y: 8.4), controlPoint2: NSPoint(x: 5.2, y: 12.4))
            arc.lineWidth = 1.7
            arc.lineCapStyle = .round
            arc.stroke()
            // A faint empty cell, bottom right: the grid the tile belongs to.
            NSColor.black.withAlphaComponent(0.45).setStroke()
            let cell = NSBezierPath(roundedRect: NSRect(x: 10.1, y: 2.1, width: 5.8, height: 5.3), xRadius: 1.5, yRadius: 1.5)
            cell.lineWidth = 1.1
            cell.stroke()
            if badged {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 1, y: 13, width: 4.6, height: 4.6)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = badged ? "Sweep, update available" : "Sweep"
        return image
    }
}
