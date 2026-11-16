import AppKit
import SwiftUI
import SweepCore

/// A click-through overlay with the snap preview and a label, shown while a gesture is live.
@MainActor
final class TooltipOverlay {
    private var panel: NSPanel?
    private var cursorHidden = false

    func show(_ tooltip: Tooltip, cursor: CGPoint, hideCursor: Bool) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        // Top-left global → AppKit bottom-left.
        let area = tooltip.preview ?? CGRect(x: cursor.x - 150, y: cursor.y + 24, width: 300, height: 60)
        let frame = NSRect(x: area.minX, y: primaryHeight - area.maxY, width: area.width, height: area.height)
        let p = panel ?? makePanel()
        p.setFrame(frame, display: false)
        p.contentView = NSHostingView(rootView: TooltipView(tooltip: tooltip))
        p.orderFrontRegardless()
        panel = p
        if hideCursor, !cursorHidden { NSCursor.hide(); cursorHidden = true }
    }

    func hide() {
        panel?.orderOut(nil)
        if cursorHidden { NSCursor.unhide(); cursorHidden = false }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return p
    }
}

private struct TooltipView: View {
    let tooltip: Tooltip

    var body: some View {
        ZStack {
            if tooltip.preview != nil {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Brand.accent.opacity(0.20))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Brand.accent.opacity(0.85), lineWidth: 2))
            }
            Text(tooltip.label)
                .font(.system(size: tooltip.fontSize, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Brand.accent.opacity(0.5), lineWidth: 1))
        }
        .padding(4)
    }
}
