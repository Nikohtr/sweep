import os
import AppKit
import ApplicationServices
import SweepCore

// Menu bar app shell. The loop adds features step by step.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    /// Problem rows: hidden while all is well (see `MenuBarPolicy.problem`).
    private let problemItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let fixItem = NSMenuItem(title: "", action: #selector(fixProblem), keyEquivalent: "")
    private let problemSeparator = NSMenuItem.separator()
    private var inputFailed = false
    private let store = SettingsStore(defaults: .sweepStandard())
    private lazy var input = InputTap(config: store.settings.recognizerConfig)
    private let updater = Updater()
    /// Shown only while an update waits (see `UpdatePolicy.menuTitle`).
    private let updateAvailableItem = NSMenuItem(title: "", action: #selector(checkForUpdates), keyEquivalent: "")
    private let updateSeparator = NSMenuItem.separator()
    private lazy var settingsWindow = SettingsWindowController(store: store, updater: updater)
    private lazy var tutorialWindow = TutorialWindowController(store: store, permission: permission)
    private let tooltip = TooltipOverlay()
    private lazy var layoutKeeper = LayoutKeeper { [unowned self] in self.store.settings }
    private let hotkeys = HotkeyCenter()
    private lazy var hotkeySequence = HotkeySequence(settings: store.settings)
    /// On a first launch the Welcome window asks for Accessibility, so no system dialog at launch.
    private lazy var permission = PermissionController(
        promptAtLaunch: !Tutorial.shouldShowOnLaunch(settings: store.settings))
    private var lastAction: WindowAction?
    /// A titlebar press on a snapped window, waiting to see if it becomes a drag.
    private var pendingUnsnap: (key: WindowKey, down: CGPoint)?
    /// Window chained by tap-and-hold on a Dock icon, for the rest of that gesture.
    private var chainedWindow: AXUIElement?
    /// A tab detach is running; its new window becomes `chainedWindow` if the gesture is still going.
    private var detachPending = false
    private let enableItem = NSMenuItem(title: "Enable Gestures", action: #selector(toggleGestures), keyEquivalent: "")
    private let ignoreItem = NSMenuItem(title: "Pause Sweep in This App", action: #selector(toggleIgnore), keyEquivalent: "")
    private let undoItem = NSMenuItem(title: "Undo Window Move", action: #selector(undoWindowMove), keyEquivalent: "")
    private var ignoreTarget: (id: String, name: String)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXHitTester.installTimeouts()   // A hung app must not stall input
        if MoveCheck.runAtLaunch() { return }   // Relaunching from Applications
        NSApp.applicationIconImage = Brand.appIcon
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Brand.menuBarGlyph()
        let menu = NSMenu()
        updateAvailableItem.target = self
        menu.addItem(updateAvailableItem)
        menu.addItem(updateSeparator)
        problemItem.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        fixItem.target = self
        menu.addItem(problemItem)
        menu.addItem(fixItem)
        menu.addItem(problemSeparator)
        refreshProblem()
        enableItem.target = self
        enableItem.state = store.settings.gesturesEnabled ? .on : .off
        menu.addItem(enableItem)
        ignoreItem.target = self
        menu.addItem(ignoreItem)
        undoItem.target = self
        menu.addItem(undoItem)
        menu.addItem(.separator())
        menu.delegate = self
        if updater.isEnabled {
            let checkItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            checkItem.target = self
            menu.addItem(checkItem)
        }
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Sweep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        updater.iconVisible = { [weak self] in self?.statusItem?.isVisible ?? false }
        updater.onPendingChange = { [weak self] _ in self?.refreshUpdateRow() }
        refreshUpdateRow()
        item.isVisible = MenuBarPolicy.iconVisible(settings: store.settings)

        store.onChange = { [weak self] settings in
            self?.input.updateConfig(settings.recognizerConfig)
            self?.input.disableMouse = settings.disableMagicMouse
            if let self, EventBlockPolicy.needsActiveTap(settings: settings) != self.input.activeListener {
                // The tap kind is fixed at creation, so make a new one.
                self.input.activeListener = EventBlockPolicy.needsActiveTap(settings: settings)
                if self.input.isRunning { self.input.stop(); self.startInput() }
            }
            self?.statusItem?.isVisible = MenuBarPolicy.iconVisible(settings: settings)
            self?.enableItem.state = settings.gesturesEnabled ? .on : .off
            self?.hotkeys.update(settings: settings)
            self?.hotkeySequence = HotkeySequence(settings: settings)
            self?.updateIcon()
        }
        input.disableMouse = store.settings.disableMagicMouse
        input.activeListener = EventBlockPolicy.needsActiveTap(settings: store.settings)
        input.onMouse = { [weak self] type, point, held in self?.handleMouse(type, at: point, held: held) }
        input.mousePolicy = { [weak self] fromMouse, held in
            guard let self else { return false }
            let roles = ModifierResolver.roles(held: held, settings: self.store.settings)
            return MouseGesturePolicy.allows(fromMouse: fromMouse, roles: roles, settings: self.store.settings)
        }
        input.onOutput = { [weak self] output, context, steps in
            self?.act(output, context: context, steps: steps)
            self?.show(output, context: context)
        }
        input.contextProvider = { [weak self] cursor, modifiers in
            guard let self else { return nil }
            guard let (info, window) = AXHitTester.hitWithWindow(at: cursor).map({ ($0.info, $0.window) }) else {
                // The app under the cursor did not answer in time. No context: the events pass through.
                Log.gesture.debug("\(SweepLog.dropped, privacy: .public)")
                return nil
            }
            return GestureGate.origin(hit: info, held: modifiers, settings: self.store.settings).map {
                GestureContext(origin: $0, window: window, modifiers: modifiers,
                               app: $0 == .dock ? AXHitTester.dockApp(at: cursor)
                                   : $0 == .appMenu ? NSWorkspace.shared.frontmostApplication : nil,
                               cursor: cursor,
                               tab: $0 == .tab ? AXHitTester.tab(at: cursor) : nil,
                               title: $0 == .missionControl ? AXHitTester.title(at: cursor) : nil)
            }
        }
        permission.onStartInput = { [weak self] in self?.startInput() }
        permission.onStopInput = { [weak self] in self?.input.stop() }
        permission.onStatusChange = { [weak self] status in self?.showPermission(status) }
        permission.begin()
        layoutKeeper.start()
        hotkeys.onKey = { [weak self] code in self?.handleHotkey(code) }
        store.onShowTutorial = { [weak self] in self?.tutorialWindow.show() }
        if Tutorial.shouldShowOnLaunch(settings: store.settings) { tutorialWindow.show() }
        store.onRestartInput = { [weak self] in
            self?.input.stop()
            self?.startInput()
        }
        hotkeys.update(settings: store.settings)
    }

    /// Super modifier + direction key snaps the front window; the center key centers it.
    private func handleHotkey(_ code: UInt16) {
        let settings = store.settings
        if code == HotkeyMap.undoKeyCode, settings.undoHotkey {
            WindowMover.undoLast()
            return
        }
        WindowMover.undoGroup += 1   // each key press is its own undo step
        guard let app = NSWorkspace.shared.frontmostApplication,
              !settings.ignoredApps.contains(app.bundleIdentifier ?? ""),
              let window = AppWindows.focusedWindow(of: app) else { return }
        let action: WindowAction?
        if code == HotkeyMap.keyCode(for: settings.centerKey) {
            action = hotkeySequence.pressCenter()
        } else if let direction = HotkeyMap.direction(keyCode: code, keys: settings.arrowKeys) {
            action = hotkeySequence.press(direction, at: ProcessInfo.processInfo.systemUptime)
        } else {
            action = nil
        }
        if let action { WindowMover.run(action, on: window, settings: settings) }
    }

    /// Opening Sweep again from Finder or Launchpad shows the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if MenuBarPolicy.openSettingsOnReopen(iconVisible: statusItem?.isVisible ?? false) {
            settingsWindow.show()
        }
        return false
    }

    /// Sets the ignore item for the app that is in front while the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let app = NSWorkspace.shared.frontmostApplication
        if let app, let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier {
            let name = app.localizedName ?? id
            ignoreTarget = (id, name)
            ignoreItem.title = IgnoreList.menuTitle(appName: name, ignored: store.settings.ignoredApps.contains(id))
            ignoreItem.isHidden = false
        } else {
            ignoreTarget = nil
            ignoreItem.isHidden = true
        }
        undoItem.isHidden = WindowMover.undo.isEmpty
    }

    @objc private func undoWindowMove() { WindowMover.undoLast() }

    @objc private func toggleIgnore() {
        guard let target = ignoreTarget else { return }
        IgnoreList.toggle(target.id, in: &store.settings.ignoredApps)
    }

    @objc private func toggleGestures() {
        store.settings.gesturesEnabled.toggle()
    }

    private func updateIcon() {
        statusItem?.button?.appearsDisabled = MenuBarPolicy.iconDimmed(
            gesturesEnabled: store.settings.gesturesEnabled, permissionGranted: permission.status == .granted)
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }

    /// The "Update Available" row and the icon badge follow `updater.pendingVersion`.
    private func refreshUpdateRow() {
        let title = UpdatePolicy.menuTitle(pendingVersion: updater.pendingVersion)
        updateAvailableItem.title = title ?? ""
        updateAvailableItem.isHidden = title == nil
        updateSeparator.isHidden = title == nil
        statusItem?.button?.image = Brand.menuBarGlyph(badged: title != nil)
    }

    @objc private func fixProblem() {
        switch MenuBarPolicy.problem(permission: permission.status, inputFailed: inputFailed)?.fix {
        case .grantAccess: permission.requestFromUser()
        case .retryInput: input.stop(); startInput()
        case nil: break
        }
    }

    private func startInput() {
        inputFailed = !input.start()
        if inputFailed { Log.app.error("Sweep: could not start input") }
        refreshProblem()
    }

    private func showPermission(_ status: PermissionFlow.Status) {
        refreshProblem()
        updateIcon()
    }

    private func refreshProblem() {
        let problem = MenuBarPolicy.problem(permission: permission.status, inputFailed: inputFailed)
        problemItem.title = problem?.message ?? ""
        fixItem.title = problem?.fixTitle ?? ""
        for item in [problemItem, fixItem, problemSeparator] { item.isHidden = problem == nil }
    }

    /// Applies the action of the steps so far, live, once per change; on lift, applies the final action.
    private func act(_ output: RecognizerOutput, context: GestureContext?, steps: [Primitive]) {
        // A finished or cancelled gesture starts the next one fresh.
        let gestureOver: Bool
        if case .step = output { gestureOver = false } else { gestureOver = true }
        defer {
            if gestureOver {
                lastAction = nil; chainedWindow = nil; detachPending = false; tooltip.hide()
                WindowMover.undoGroup += 1   // The next gesture is a new undo step
            }
        }
        guard let context else { return }
        let roles = ModifierResolver.roles(held: context.modifiers, settings: store.settings)
        if context.origin == .menubar {
            actOnMenubar(output, cursor: context.cursor, steps: steps, roles: roles)
            return
        }
        if context.origin == .missionControlSpace {
            moveSpace(output, from: context.cursor, steps: steps)
            return
        }
        if context.origin == .missionControl {
            actInMissionControl(output, title: context.title, steps: steps)
            return
        }
        if context.origin == .dock || context.origin == .appMenu {
            // With the super modifier the gesture acts on the app's front window.
            if let superSteps = DockActions.superWindowSteps(steps, roles: roles), let app = context.app,
               let window = AppWindows.focusedWindow(of: app) ?? AppWindows.windows(of: app).first {
                applyWindowGesture(output, steps: superSteps, roles: roles, window: window)
                return
            }
            // Tap and hold chained a window: the rest of the gesture is a window gesture on it.
            if let chained = DockActions.chainedSteps(steps), !chained.isEmpty, let window = chainedWindow {
                applyWindowGesture(output, steps: chained, roles: roles, window: window)
            } else {
                actOnDock(output, app: context.app, steps: steps, roles: roles)
            }
            return
        }
        if context.origin == .tab, let tab = context.tab {
            // Tap and hold detaches the tab; the rest of the gesture then moves the new window.
            if case .step(let step) = output, TabActions.liveAction(newStep: step, steps: steps) == .detachTab {
                detachTab(tab, cursor: context.cursor)
                return
            }
            if let chained = TabActions.chainedSteps(steps) {
                if !chained.isEmpty, let window = chainedWindow {
                    applyWindowGesture(output, steps: chained, roles: roles, window: window)
                }
                return
            }
            if case .ended = output, let tabAction = TabActions.finalAction(for: steps) {
                runTab(tab, action: tabAction)
                return
            }
        }
        guard let window = context.window, [.titlebar, .toolbar, .window, .tab].contains(context.origin) else { return }
        applyWindowGesture(output, steps: steps, roles: roles, window: window)
    }

    /// While the fingers are down, preview what lifting them would do.
    private func showTooltip(_ output: RecognizerOutput, steps: [Primitive], roles: Set<ModifierRole>,
                             window: AXUIElement) {
        guard case .step = output, let frame = AXHitTester.frame(window) else { tooltip.hide(); return }
        let settings = store.settings
        let screens = AXHitTester.screens()
        guard let i = SnapLayout.screenIndex(for: frame, screens: screens.map(\.frame)) else { return }
        let preview = TitlebarActions.finalAction(for: steps, roles: roles, settings: settings)
        guard let tip = TooltipPlan.make(action: preview, windowFrame: frame, visible: screens[i].visible,
                                         settings: settings, stageManagerOn: WindowMover.stageManagerOn()) else {
            tooltip.hide(); return
        }
        tooltip.show(tip, cursor: CGEvent(source: nil)?.location ?? .zero, hideCursor: settings.hideCursor)
    }

    /// Drags the tab out, then picks up the app's new focused window for the rest of the gesture.
    private func detachTab(_ tab: AXUIElement, cursor: CGPoint) {
        guard let frame = AXHitTester.frame(tab) else { return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(tab, &pid) == .success, let app = NSRunningApplication(processIdentifier: pid) else { return }
        detachPending = true
        SpaceMover.run(TabDetachPlan.steps(tab: frame, cursor: cursor)[...])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.detachPending else { return }
            self.chainedWindow = AppWindows.focusedWindow(of: app)
        }
    }

    /// Tab gestures: select the tab when the action is about it (close), make its app frontmost, post the chord.
    private func runTab(_ tab: AXUIElement, action: TabAction) {
        if action.selectsTabFirst { AXUIElementPerformAction(tab, kAXPressAction as CFString) }
        var pid: pid_t = 0
        if AXUIElementGetPid(tab, &pid) == .success { NSRunningApplication(processIdentifier: pid)?.activate() }
        guard let chord = action.chord else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { KeyPoster.post(chord) }
    }

    /// Titlebar-style gesture on one window: live snaps, final actions on lift, haptics.
    private func applyWindowGesture(_ output: RecognizerOutput, steps: [Primitive], roles: Set<ModifierRole>,
                                    window: AXUIElement) {
        // After a snap, on lift: activate the window and/or move the cursor to it.
        defer {
            if AfterSnap.applies(output: output, lastAction: lastAction) {
                WindowMover.afterSnap(window, steps: AfterSnap.steps(settings: store.settings))
            }
        }
        let action: WindowAction?
        switch output {
        case .step: action = TitlebarActions.action(for: steps, roles: roles, settings: store.settings)
        case .ended: action = TitlebarActions.finalAction(for: steps, roles: roles, settings: store.settings)
        case .cancelled: action = nil
        }
        showTooltip(output, steps: steps, roles: roles, window: window)
        if HapticPolicy.shouldTap(output: output, previousAction: lastAction, newAction: action,
                                  enabled: store.settings.hapticFeedback) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        guard let action, action != lastAction else { return }
        lastAction = action
        WindowMover.run(action, on: window, settings: store.settings)
    }

    /// Drag to unsnap: a press on a snapped window's titlebar that moves past the threshold restores the
    /// window's pre-snap size under the cursor, once.
    private func handleMouse(_ type: NSEvent.EventType, at point: CGPoint, held: ModifierKeys) {
        switch type {
        case .leftMouseDown:
            pendingUnsnap = nil
            guard DragUnsnap.applies(settings: store.settings, held: held) else { return }
            guard let (info, window) = AXHitTester.hitWithWindow(at: point).map({ ($0.info, $0.window) }),
                  let window, let origin = OriginClassifier.classify(info),
                  origin == .titlebar || origin == .toolbar else { return }
            let key = WindowKey(element: window)
            if WindowMover.memory.original(key) != nil { pendingUnsnap = (key, point) }
        case .leftMouseDragged:
            guard let pending = pendingUnsnap, DragUnsnap.dragStarted(from: pending.down, to: point),
                  let original = WindowMover.memory.original(pending.key),
                  let current = AXHitTester.frame(pending.key.element) else { return }
            pendingUnsnap = nil
            WindowMover.undoGroup += 1
            WindowMover.undo.record(pending.key, frame: current, group: WindowMover.undoGroup)
            WindowMover.memory.forget(pending.key)
            WindowMover.snappedFrames[pending.key] = nil
            WindowMover.setFrame(DragUnsnap.frame(originalSize: original.size, current: current, cursor: point),
                                 of: pending.key.element)
        default:
            pendingUnsnap = nil
            if type == .leftMouseUp, store.settings.resizeAdjacent { WindowMover.resizeAdjacentAfterDrag() }
        }
    }

    /// Index of the screen under `cursor`.
    private func here(_ cursor: CGPoint) -> Int? {
        AXHitTester.screens().map(\.frame).firstIndex { $0.contains(cursor) }
    }

    /// Drag the Space thumbnail under the gesture to the neighbour screen's Spaces bar.
    private func moveSpace(_ output: RecognizerOutput, from start: CGPoint, steps: [Primitive]) {
        guard case .ended = output, let direction = MissionControlSpaces.direction(for: steps) else { return }
        let screens = AXHitTester.screens().map(\.frame)
        guard let i = screens.firstIndex(where: { $0.contains(start) }),
              let j = ScreenLayout.neighbor(of: i, direction: direction, screens: screens) else { return }
        let cursor = CGEvent(source: nil)?.location ?? start
        SpaceMover.run(SpaceDragPlan.steps(from: start, to: SpaceDragPlan.target(screen: screens[j]), cursor: cursor)[...])
    }

    /// On lift, find the window behind the thumbnail, leave Mission Control, then act on it.
    private func actInMissionControl(_ output: RecognizerOutput, title: String?, steps: [Primitive]) {
        guard case .ended = output, let title, let action = MissionControlActions.finalAction(for: steps) else { return }
        let windows = AXHitTester.titledWindows()
        guard let i = WindowMatch.best(title: title, candidates: windows.map(\.title)) else { return }
        let window = windows[i].window
        KeyPoster.post(KeyChord(keyCode: 53, modifiers: []))   // Esc leaves Mission Control
        let settings = store.settings
        DispatchQueue.main.asyncAfter(deadline: .now() + MissionControlActions.leaveDelay) {
            MainActor.assumeIsolated { WindowMover.run(action, on: window, settings: settings) }
        }
    }

    /// Drive the system app switcher by holding ⌘ for the length of the gesture.
    private func runSwitcher(_ event: MenubarSwitcher.Event) {
        switch event {
        case .open:
            KeyPoster.command(down: true)
            KeyPoster.post(KeyChord(keyCode: 48, modifiers: [.command]))
        case .step(let forward):
            KeyPoster.post(KeyChord(keyCode: 48, modifiers: forward ? [.command] : [.command, .shift]))
        case .close:
            KeyPoster.command(down: false)
        case .dismiss:
            KeyPoster.post(KeyChord(keyCode: 53, modifiers: [.command]))
            KeyPoster.command(down: false)
        }
    }

    /// Empty menu bar gestures act on all snapped windows of a screen, on lift.
    private func actOnMenubar(_ output: RecognizerOutput, cursor: CGPoint, steps: [Primitive],
                              roles: Set<ModifierRole>) {
        let switcher: MenubarSwitcher.Event?
        switch output {
        case .step(let step): switcher = MenubarSwitcher.live(newStep: step, steps: steps)
        case .ended: switcher = MenubarSwitcher.end(steps: steps)
        case .cancelled: switcher = MenubarSwitcher.cancel(steps: steps)
        }
        if let switcher {
            // With "switch apps" off the gesture does nothing (it does not fall through to another action).
            if let allowed = MenubarSwitcher.allowed(switcher, settings: store.settings) { runSwitcher(allowed) }
            return
        }
        guard case .ended = output,
              let action = MenubarActions.allowed(MenubarActions.finalAction(for: steps, roles: roles),
                                                  settings: store.settings) else { return }
        switch action {
        case .unsnapAll(let allScreens):
            let screens = AXHitTester.screens().map(\.frame)
            guard let here = here(cursor) else { return }
            let current = WindowMover.memory.keys.compactMap { key in AXHitTester.frame(key.element).map { (key, $0) } }
            for key in MenubarPlan.unsnapTargets(current: current, screens: screens, screenIndex: here,
                                                 allScreens: allScreens) {
                WindowMover.run(.center, on: key.element, settings: store.settings)
            }
        case .moveSnappedToScreen(let direction):
            let screens = AXHitTester.screens().map(\.frame)
            guard let here = here(cursor) else { return }
            let current = WindowMover.memory.keys.compactMap { key in AXHitTester.frame(key.element).map { (key, $0) } }
            for key in MenubarPlan.unsnapTargets(current: current, screens: screens, screenIndex: here, allScreens: false) {
                WindowMover.run(.moveToScreen(direction), on: key.element, settings: store.settings)
            }
        case .switchApp(let forward):
            KeyPoster.post(.appSwitch(forward: forward))
        case .minimizeAll(let allScreens):
            AppWindows.setMinimizedEverywhere(true, screenIndex: here(cursor), allScreens: allScreens)
        case .unminimizeAll(let allScreens):
            AppWindows.setMinimizedEverywhere(false, screenIndex: here(cursor), allScreens: allScreens)
        }
    }

    /// Dock icon gestures act on the app behind the icon, on lift.
    private func actOnDock(_ output: RecognizerOutput, app: NSRunningApplication?, steps: [Primitive],
                           roles: Set<ModifierRole>) {
        guard let app else { return }
        let action: AppAction?
        switch output {
        case .step(let step): action = DockActions.liveAction(newStep: step, steps: steps, roles: roles)
        case .ended: action = DockActions.finalAction(for: steps, roles: roles)
        case .cancelled: action = nil
        }
        guard let action = DockActions.allowed(action, settings: store.settings) else { return }
        switch action {
        case .quit:
            app.terminate()
        case .hide:
            app.hide()
        case .hideOthers:
            let running = NSWorkspace.shared.runningApplications
            let refs = running.map { AppRef(id: String($0.processIdentifier), regular: $0.activationPolicy == .regular) }
            let hide = Set(DockActions.othersToHide(target: String(app.processIdentifier), running: refs,
                                                    selfID: String(ProcessInfo.processInfo.processIdentifier)))
            app.activate()
            running.filter { hide.contains(String($0.processIdentifier)) }.forEach { $0.hide() }
        case .minimizeFront: AppWindows.setMinimized(true, all: false, app: app)
        case .minimizeAll: AppWindows.setMinimized(true, all: true, app: app)
        case .unminimizeLast: AppWindows.setMinimized(false, all: false, app: app)
        case .unminimizeAll: AppWindows.setMinimized(false, all: true, app: app)
        case .cycleWindows(let forward): AppWindows.cycle(forward: forward, app: app)
        case .activate:
            app.activate()
            chainedWindow = AppWindows.focusedWindow(of: app) ?? AppWindows.windows(of: app).first
            if store.settings.hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }

    private func show(_ output: RecognizerOutput, context: GestureContext?) {
        let roles = context.map { ModifierResolver.roles(held: $0.modifiers, settings: store.settings) } ?? []
        let place = SweepLog.place(origin: context.map { "\($0.origin)" },
                                   roles: ModifierRole.allCases.filter(roles.contains).map(\.rawValue))
        // Gesture names and places only: no window titles or paths. Public, so `log stream` shows them.
        switch output {
        case .step(let p):
            Log.gesture.debug("\(SweepLog.step(String(describing: p)), privacy: .public)")
        case .ended(let steps):
            Log.gesture.debug("\(SweepLog.ended(place: place, steps: steps.map { String(describing: $0) }), privacy: .public)")
        case .cancelled:
            Log.gesture.debug("\(SweepLog.cancelled(place: place), privacy: .public)")
        }
    }
}

/// Unified logging (subsystem = bundle ID). Stream with `SweepLog.streamCommand`.
enum Log {
    static let gesture = Logger(subsystem: SweepLog.subsystem, category: SweepLog.gestureCategory)
    static let app = Logger(subsystem: SweepLog.subsystem, category: SweepLog.appCategory)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
