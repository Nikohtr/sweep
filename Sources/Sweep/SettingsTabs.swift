import AppKit
import SwiftUI
import SweepCore

// The six settings tabs. Grouping: where the gesture happens (Gestures), where windows go (Layout),
// which keys change it (Keys), where Sweep is paused (Apps).

struct GeneralTab: View {
    @ObservedObject var store: SettingsStore
    @State private var loginStatus = LoginItem.status
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Sweep") {
                Explained(loginError ?? LoginItemPlan.message(for: loginStatus) ?? "Start Sweep when you log in.") {
                    Toggle("Open at login", isOn: Binding(
                        get: { LoginItemPlan.isOn(loginStatus) },
                        set: { on in
                            loginError = LoginItem.set(on)
                            loginStatus = LoginItem.status
                            store.settings.launchAtLogin = LoginItemPlan.isOn(loginStatus)
                        }))
                }
                Explained("When the icon is hidden, open Sweep again from Finder or Launchpad to see this window.") {
                    Toggle("Show icon in the menu bar", isOn: $store.settings.showInMenuBar)
                }
                Explained("Looks at the trackpad and keyboard settings that gestures need. It changes nothing.") {
                    Button("Check System Settings…") { DiagnosticsReader.showReport() }
                }
                Explained("Save all settings and paused apps to a file, or load them on another Mac.") {
                    HStack {
                        Button("Export Settings…") { SettingsTransfer.export(store) }
                        Button("Import Settings…") { SettingsTransfer.importFile(into: store) }
                    }
                }
            }
            Section("Feel") {
                Explained("Lower it if gestures start when you did not mean them to.") {
                    Slider(value: Binding(get: { Double(store.settings.sensitivity) },
                                          set: { store.settings.sensitivity = Int($0.rounded()) }),
                           in: 1...4, step: 1) {
                        Text("Sensitivity")
                    } minimumValueLabel: {
                        Text("Low")
                    } maximumValueLabel: {
                        Text("High")
                    }
                }
                Explained("Rest your fingers this long, or press Esc, to let go of a gesture without acting.") {
                    IntSlider(title: "Let go after", value: $store.settings.cancelTimeoutMs,
                              range: SweepSettings.cancelTimeoutRange, step: SettingsFormat.cancelTimeoutStepMs,
                              valueText: { SettingsFormat.seconds(ms: $0) })
                }
                Explained("A light tap on the trackpad at each step. Force Touch trackpads only, and the system setting must allow it.") {
                    Toggle("Haptic feedback", isOn: $store.settings.hapticFeedback)
                }
                Explained("Rest two fingers to begin a hold gesture. Turn it off if it gets in the way of right-clicks.") {
                    Toggle("Tap and hold", isOn: $store.settings.tapHold)
                }
            }
            Section("While you gesture") {
                Toggle("Show what will happen", isOn: $store.settings.tooltipsEnabled)
                IntSlider(title: "Label size", value: $store.settings.tooltipSize, range: SweepSettings.tooltipSizeRange)
                    .disabled(!store.settings.tooltipsEnabled)
                Toggle("Outline where the window will go", isOn: $store.settings.liveTooltips)
                    .disabled(!store.settings.tooltipsEnabled)
                Toggle("Hide the pointer meanwhile", isOn: $store.settings.hideCursor)
                    .disabled(!store.settings.tooltipsEnabled)
            }
        }
        .formStyle(.grouped)
        .onAppear { loginStatus = LoginItem.status }
    }
}

struct GesturesTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section("On a titlebar: snapping") {
                Text("Two fingers on a window's titlebar. Hold the Anywhere key to use the whole window.")
                    .font(.caption).foregroundStyle(.secondary)
                GestureToggles(kinds: GestureKind.snapping, store: store)
            }
            Section("On a titlebar: windows") {
                GestureToggles(kinds: GestureKind.window, store: store)
            }
            Section("On a Dock icon") {
                Text("Pinch in to quit the app, double tap to hide it, swipe down or up to minimize or bring back "
                     + "its windows, swipe left or right to go through them. Tap and hold to bring the app forward "
                     + "and go on with a window gesture.")
                    .font(.caption).foregroundStyle(.secondary)
                DockMenuToggles(kinds: DockMenuGestureKind.dock, store: store)
                Explained("The same gestures also work on the app's name, next to the Apple menu.") {
                    Toggle("On the app menu too", isOn: $store.settings.appMenuGestures)
                }
            }
            Section("On the menu bar") {
                Text("Use these on an empty part of the menu bar.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(GestureHelp.menubar.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.gesture)
                            if let role = row.role {
                                Text("+ " + GestureHelp.modifierLabel(role, settings: store.settings))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(row.action).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    }
                }
                DockMenuToggles(kinds: DockMenuGestureKind.menubar, store: store)
            }
            Section("On a tab") {
                Text("Pinch in to close the tab, pinch out for a new one, tap and hold to pull it into its own window.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(TabApp.allCases, id: \.self) { kind in
                    Toggle(kind.title, isOn: Binding(
                        get: { !store.settings.disabledTabApps.contains(kind) },
                        set: { on in
                            store.settings.disabledTabApps.removeAll { $0 == kind }
                            if !on { store.settings.disabledTabApps.append(kind) }
                        }))
                }
            }
            Section("In Mission Control") {
                Explained("On a window preview: pinch in closes, swipe down minimizes, swipe left, right or up snaps.") {
                    Toggle("Gestures in Mission Control and App Exposé", isOn: $store.settings.missionControlGestures)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct LayoutTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section("Grid") {
                Explained("Space between snapped windows, and between windows and the screen edge if that is on.") {
                    IntSlider(title: "Gap", value: $store.settings.gridSpacing, range: SweepSettings.gridSpacingRange,
                              valueText: { "\($0) pt" })
                }
                Toggle("Gap at the screen edges too", isOn: $store.settings.gridIncludesScreenEdges)
                Toggle("Swipe up leaves a small margin", isOn: $store.settings.swipeUpFillsAlmost)
            }
            Section("After a snap") {
                Toggle("Bring the window to the front", isOn: $store.settings.activateAfterSnap)
                Toggle("Move the pointer to the window", isOn: $store.settings.moveCursorAfterSnap)
                Explained("Hold the Extend key while you drag to keep the snapped size.") {
                    Toggle("Dragging a snapped window gives back its old size", isOn: $store.settings.dragToUnsnap)
                }
                Toggle("Resize neighbors together", isOn: $store.settings.resizeAdjacent)
            }
            Section("macOS tiling") {
                Explained("Halves and fill use the system's own tiles (macOS 15 or later, gap 0). Sweep places the other snaps.") {
                    Toggle("Use macOS tiling when it can", isOn: $store.settings.nativeTiling)
                }
            }
            Section("Displays") {
                Text("Hold the Display key and swipe to send a window to the display on that side.")
                    .font(.caption).foregroundStyle(.secondary)
                Explained("Keep swiping after the move to snap the window on its new display.") {
                    Toggle("Keep going after the move", isOn: $store.settings.screensChainGesture)
                }
                Toggle("Pointer follows the window", isOn: $store.settings.screensMoveCursor)
                Explained("When a display comes back, its windows go back to where they were. 0 turns this off.") {
                    IntSlider(title: "Restore windows after", value: $store.settings.externalDisplayTimeout,
                              range: SweepSettings.externalDisplayTimeoutRange,
                              valueText: { $0 == 0 ? "Off" : "\($0) s" })
                }
            }
            Section("Stage Manager") {
                Explained("When Stage Manager is on, snapped windows leave this much room on the left for recent apps.") {
                    IntSlider(title: "Room on the left", value: $store.settings.stageManagerOffset,
                              range: SweepSettings.stageManagerOffsetRange, step: 10, valueText: { "\($0) pt" })
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct KeysTab: View {
    @ObservedObject var store: SettingsStore

    private static let order: [ModifierRole] = [.general, .secondary, .tertiary, .screen, .superKey]
    private static let keys: [(ModifierKeys, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]

    var body: some View {
        Form {
            Section {
                ForEach(Self.order, id: \.self) { role in
                    Explained(GestureHelp.roleNote(role)) {
                        LabeledContent(GestureHelp.roleName(role)) {
                            HStack(spacing: 4) {
                                ForEach(Self.keys, id: \.1) { key, symbol in
                                    Toggle(symbol, isOn: binding(role, key)).toggleStyle(.button)
                                }
                            }
                        }
                    }
                }
                Toggle("Only use gestures while the Anywhere key is held", isOn: $store.settings.requireSuperModifier)
                Button("Restore Default Keys") { store.settings.resetModifiers() }
            } header: {
                Text("Hold a key while you swipe")
            }
            Section("Keyboard snapping") {
                Toggle("Snap with the Anywhere key + direction keys", isOn: $store.settings.arrowHotkeys)
                Picker("Direction keys", selection: $store.settings.arrowKeys) {
                    Text("Arrows").tag(SweepSettings.ArrowKeys.arrows)
                    Text("WASD").tag(SweepSettings.ArrowKeys.wasd)
                    Text("Dvorak (, A O E)").tag(SweepSettings.ArrowKeys.dvorak)
                }
                Picker("Center key", selection: $store.settings.centerKey) {
                    Text("Esc").tag(SweepSettings.CenterKey.escape)
                    Text("Backspace").tag(SweepSettings.CenterKey.backspace)
                    Text("Return").tag(SweepSettings.CenterKey.returnKey)
                }
                Text("Press keys one after another to combine them, like swipes: ← then ↑ gives the top-left quarter. "
                     + "While this is on, these key combinations do not reach other apps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Undo") {
                Toggle("Undo the last window move with the Anywhere key + Z", isOn: $store.settings.undoHotkey)
                Text("Puts the last window that Sweep moved, resized or snapped back where it was. "
                     + "Also in the Sweep menu: Undo Window Move. While this is on, the key combination "
                     + "does not reach other apps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Input") {
                Explained("While a gesture is on, the window under the pointer does not also scroll or zoom.") {
                    Toggle("Hold back scroll and zoom during gestures", isOn: $store.settings.activeEventListener)
                }
                Explained("Only fingers on the trackpad start gestures. This stops gestures you did not mean.") {
                    Toggle("Ignore Magic Mouse (beta)", isOn: $store.settings.disableMagicMouse)
                }
                Explained("If pinch or swipe stops working, this turns the displays off and on to reset them.") {
                    Button("Reset Pinch and Swipe…") { SettingsAlerts.fixInput(store) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(_ role: ModifierRole, _ key: ModifierKeys) -> Binding<Bool> {
        Binding(get: { store.settings.keys(for: role).contains(key) },
                set: { on in
                    var k = store.settings.keys(for: role)
                    if on { k.insert(key) } else { k.remove(key) }
                    store.settings.setKeys(k, for: role)
                })
    }
}

struct AppsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section("Paused apps") {
                Text("Sweep does nothing in these apps. To pause an app, bring it to the front and choose "
                     + "“Pause Sweep in …” from the menu bar icon.")
                    .font(.caption).foregroundStyle(.secondary)
                if store.settings.ignoredApps.isEmpty {
                    Text("No paused apps.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.settings.ignoredApps, id: \.self) { id in
                        HStack {
                            Text(id)
                            Spacer()
                            Button("Resume") { IgnoreList.toggle(id, in: &store.settings.ignoredApps) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutTab: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                if let hero = Brand.image("welcome-hero") {
                    Image(nsImage: hero).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 200).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Image(nsImage: Brand.appIcon).resizable().frame(width: 96, height: 96)
                    .offset(y: 40)
            }
            .padding(.bottom, 36)
            Text("Sweep").font(.largeTitle).bold()
            Text(AppVersion.display(
                short: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String))
                .foregroundStyle(.secondary)
            UpdateControls(updater: updater)
            Text("Arrange windows with two fingers. Snap, move, minimize and close them from the titlebar, "
                 + "the Dock and the menu bar.")
                .multilineTextAlignment(.center).frame(maxWidth: 400)
            HStack {
                Button("Show Welcome") { store.onShowTutorial?() }
                Button("Restore All Settings…") { SettingsAlerts.restoreAll(store) }
            }
            .padding(.top, 4)
            HStack {
                Button("Copy Debug Info…") {
                    DebugInfo.showAndCopy(settings: store.settings, updatesOn: updater.isEnabled)
                }
                Button("Report a Problem…") { DebugInfo.reportProblem() }
                Button("Uninstall Sweep…") { Uninstaller.confirmAndRun() }
            }
            Spacer()
            HStack(spacing: 8) {
                Text(LicenseNotice.aboutLine).font(.caption).foregroundStyle(.secondary)
                Menu("Licenses") {
                    ForEach(LicenseNotice.all, id: \.resourceFile) { notice in
                        Button("\(notice.component) (\(notice.license))") { Self.open(notice) }
                            .disabled(Self.url(of: notice) == nil)
                    }
                }
                .menuStyle(.borderlessButton).fixedSize().font(.caption)
            }
        }
        .padding()
    }

    /// The license file in Contents/Resources; nil under `swift run` (no app bundle).
    private static func url(of notice: LicenseNotice) -> URL? {
        let name = notice.resourceFile as NSString
        return Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension)
    }

    private static func open(_ notice: LicenseNotice) {
        if let url = url(of: notice) { NSWorkspace.shared.open(url) }
    }
}

/// About tab: check now, and the two automatic-update switches.
private struct UpdateControls: View {
    @ObservedObject var updater: Updater

    var body: some View {
        if updater.isEnabled {
            VStack(spacing: 6) {
                Button(UpdatePolicy.menuTitle(pendingVersion: updater.pendingVersion) ?? "Check for Updates…") {
                    updater.checkForUpdates()
                }
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.automaticallyChecks }, set: { updater.automaticallyChecks = $0 }))
                Toggle("Download and install updates automatically", isOn: Binding(
                    get: { updater.automaticallyDownloads }, set: { updater.automaticallyDownloads = $0 }))
                    .disabled(!updater.automaticallyChecks)
            }
            .toggleStyle(.checkbox)
        } else {
            Text("Updates are off in this build.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
