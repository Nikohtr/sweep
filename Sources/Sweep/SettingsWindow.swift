import AppKit
import SwiftUI
import SweepCore

/// Holds the settings, saves them as JSON in UserDefaults, and tells the app about changes.
@MainActor
final class SettingsStore: ObservableObject {
    private static let key = "settings.v1"
    /// Set by the app: stops and starts the gesture input (for "Fix pinch & swipe").
    var onRestartInput: (@MainActor () -> Void)?
    /// Set by the app: opens the welcome tutorial.
    var onShowTutorial: (@MainActor () -> Void)?

    @Published var settings: SweepSettings {
        didSet {
            let fixed = settings.clamped()
            if fixed != settings { settings = fixed; return }
            save()
            onChange?(settings)
        }
    }

    var onChange: ((SweepSettings) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let load = SettingsLoad.initial(stored: defaults.data(forKey: Self.key))
        settings = load.settings
        // Write the new-install defaults at once, so a later version reads them as stored choices.
        if load.isNewInstall { save() }
    }

    private let defaults: UserDefaults

    private func save() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.key) }
    }
}

/// The settings window: General, Gestures, Layout, Keys, Apps, About.
@MainActor
final class SettingsWindowController {
    private let store: SettingsStore
    private let updater: Updater
    private var window: NSWindow?

    init(store: SettingsStore, updater: Updater) { self.store = store; self.updater = updater }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 640),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Sweep"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(store: store, updater: updater))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let updater: Updater

    var body: some View {
        TabView {
            GeneralTab(store: store).tabItem { Label("General", systemImage: "gearshape") }
            GesturesTab(store: store).tabItem { Label("Gestures", systemImage: "hand.draw") }
            LayoutTab(store: store).tabItem { Label("Layout", systemImage: "square.grid.2x2") }
            KeysTab(store: store).tabItem { Label("Keys", systemImage: "command") }
            AppsTab(store: store).tabItem { Label("Apps", systemImage: "pause.circle") }
            AboutTab(store: store, updater: updater).tabItem { Label("About", systemImage: "info.circle") }
        }
        .tint(Brand.accent)
        .padding(20)
        .frame(width: 600, height: 640)
    }
}

/// A setting with a short explanation under it.
struct Explained<Content: View>: View {
    let note: String
    @ViewBuilder let content: Content

    init(_ note: String, @ViewBuilder content: () -> Content) {
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            Text(note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A labeled slider over a whole-number setting, with its value on the right.
struct IntSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var valueText: ((Int) -> String)?
    var valueWidth: CGFloat = 52

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                       in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
                if let valueText {
                    Text(valueText(value)).monospacedDigit().frame(width: valueWidth, alignment: .trailing)
                }
            }
        }
    }
}

/// One toggle per gesture family. On = not in `disabledGestures`.
struct GestureToggles: View {
    let kinds: [GestureKind]
    @ObservedObject var store: SettingsStore

    var body: some View {
        ForEach(kinds, id: \.self) { kind in
            Toggle(kind.title, isOn: Binding(
                get: { !store.settings.disabledGestures.contains(kind) },
                set: { on in
                    store.settings.disabledGestures.removeAll { $0 == kind }
                    if !on { store.settings.disabledGestures.append(kind) }
                }))
        }
    }
}

/// One toggle per Dock or menu bar gesture. On = not in `disabledDockMenuGestures`.
struct DockMenuToggles: View {
    let kinds: [DockMenuGestureKind]
    @ObservedObject var store: SettingsStore

    var body: some View {
        ForEach(kinds, id: \.self) { kind in
            Toggle(kind.title, isOn: Binding(
                get: { store.settings.allows(kind) },
                set: { on in
                    store.settings.disabledDockMenuGestures.removeAll { $0 == kind }
                    if !on { store.settings.disabledDockMenuGestures.append(kind) }
                }))
        }
    }
}

/// Confirmations that more than one tab uses.
@MainActor
enum SettingsAlerts {
    static func restoreAll(_ store: SettingsStore) {
        let alert = NSAlert()
        alert.messageText = "Restore all settings?"
        alert.informativeText = "Every Sweep setting goes back to its default. Paused apps stay paused."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.settings = store.settings.restoredDefaults()
        }
    }

    static func fixInput(_ store: SettingsStore) {
        let alert = NSAlert()
        alert.messageText = "Reset pinch and swipe?"
        alert.informativeText = InputFix.confirmText
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let restart = store.onRestartInput ?? {}
        InputFixRunner.run(InputFix.steps[...], restartInput: restart)
    }
}

extension UserDefaults {
    /// The standard defaults, after a one-time copy of the settings that were saved under
    /// Sweep's old bundle ID (see `LegacyDefaults`).
    static func sweepStandard() -> UserDefaults {
        let standard = UserDefaults.standard
        guard Bundle.main.bundleIdentifier != LegacyDefaults.oldDomain,
              let old = UserDefaults(suiteName: LegacyDefaults.oldDomain) else { return standard }
        let oldValues = old.dictionaryRepresentation()
        let copy = LegacyDefaults.keysToCopy(
            old: Set(oldValues.keys), new: Set(standard.dictionaryRepresentation().keys))
        for key in copy { standard.set(oldValues[key], forKey: key) }
        return standard
    }
}
