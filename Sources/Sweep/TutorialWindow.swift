import AppKit
import SwiftUI
import SweepCore

/// The welcome tutorial, a small paged window.
@MainActor
final class TutorialWindowController {
    private let store: SettingsStore
    private let permission: PermissionController
    private var window: NSWindow?

    init(store: SettingsStore, permission: PermissionController) {
        self.store = store
        self.permission = permission
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Welcome to Sweep"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: TutorialView(permission: permission) { [weak self] in self?.finish() })
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        store.settings.tutorialSeen = true
        window?.close()
    }
}

struct TutorialView: View {
    @ObservedObject var permission: PermissionController
    let onDone: () -> Void
    @State private var index: Int

    init(permission: PermissionController, startAt index: Int = 0, onDone: @escaping () -> Void) {
        self.permission = permission
        self.onDone = onDone
        _index = State(initialValue: index)
    }

    var body: some View {
        let page = Tutorial.pages[index]
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let name = page.art, let art = Brand.image(name) {
                    Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(nsColor: Brand.cream)
                }
            }
            .frame(width: 640, height: 300)
            .clipped()
            .id(index)
            .transition(.opacity)

            VStack(alignment: .leading, spacing: 12) {
                Text(page.title).font(.title2).bold()
                Text(page.body).fixedSize(horizontal: false, vertical: true)
                if page.kind == .permission {
                    PermissionStep(permission: permission)
                }
                ForEach(Array(page.rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.role.map { "\(row.gesture) + \(GestureHelp.roleName($0)) key" } ?? row.gesture)
                        Spacer()
                        Text(row.action).foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                Spacer(minLength: 0)
                HStack {
                    HStack(spacing: 6) {
                        ForEach(Tutorial.pages.indices, id: \.self) { i in
                            Circle().fill(i == index ? Brand.accent : Color.secondary.opacity(0.3))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .accessibilityLabel("Page \(index + 1) of \(Tutorial.pages.count)")
                    Spacer()
                    if let prev = Tutorial.previous(before: index) {
                        Button("Back") { withAnimation(.easeInOut(duration: 0.25)) { index = prev } }
                    }
                    let granted = permission.status == .granted
                    let label = Tutorial.nextLabel(at: index, granted: granted)
                    // While the permission page waits, Return belongs to its Allow button.
                    let waiting = page.kind == .permission && !granted
                    if let next = Tutorial.next(after: index) {
                        Button(label) { withAnimation(.easeInOut(duration: 0.25)) { index = next } }
                            .keyboardShortcut(waiting ? nil : .defaultAction)
                    } else {
                        Button(label) { onDone() }.keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(24)
        }
        .tint(Brand.accent)
        .frame(width: 640, height: 600)
    }
}

/// The live Accessibility status on the Welcome window, with the button that asks for it.
private struct PermissionStep: View {
    @ObservedObject var permission: PermissionController

    var body: some View {
        HStack(spacing: 12) {
            if permission.status == .granted {
                Label("Sweep can move windows", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Brand.accent)
                    .font(.headline)
            } else {
                Label("Not allowed yet", systemImage: "circle.dashed")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                Spacer()
                Button("Allow…") { permission.requestFromUser() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: permission.status)
        Text(permission.status == .granted
             ? "All set. You can turn this off later in System Settings."
             : "Click Allow, turn on Sweep in the list, then come back. This page updates by itself.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
