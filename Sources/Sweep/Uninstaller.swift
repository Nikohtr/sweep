import AppKit
import SweepCore

/// Settings › About › Uninstall Sweep…. Runs `UninstallPlan` after a confirm alert.
@MainActor
enum Uninstaller {
    static func confirmAndRun() {
        let location = MoveCheck.currentLocation()
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = UninstallPlan.confirmTitle
        alert.informativeText = UninstallPlan.confirmText(trashesApp: UninstallPlan.trashesApp(location))
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let steps = UninstallPlan.steps(bundleID: Bundle.main.bundleIdentifier ?? SweepLog.subsystem,
                                        appPath: Bundle.main.bundlePath, location: location,
                                        homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path)
        run(steps[...])
    }

    /// One step at a time; the Trash step waits for Finder before the app quits.
    private static func run(_ steps: ArraySlice<UninstallPlan.Step>) {
        guard let step = steps.first else { return }
        let rest = steps.dropFirst()
        switch step {
        case .trashApp(let path):
            NSWorkspace.shared.recycle([URL(fileURLWithPath: path)]) { _, _ in
                DispatchQueue.main.async { run(rest) }
            }
            return
        case .quit:
            NSApp.terminate(nil)
            return
        default:
            if !perform(step), let fallback = UninstallPlan.fallback(for: step) { _ = perform(fallback) }
            run(rest)
        }
    }

    /// True when the step worked.
    private static func perform(_ step: UninstallPlan.Step) -> Bool {
        switch step {
        case .unregisterLoginItem:
            return LoginItem.set(false) == nil
        case .resetAccessibility(let bundleID):
            let tccutil = Process()
            tccutil.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            tccutil.arguments = UninstallPlan.tccutilArguments(bundleID: bundleID)
            guard (try? tccutil.run()) != nil else { return false }
            tccutil.waitUntilExit()
            return tccutil.terminationStatus == 0
        case .openAccessibilitySettings:
            if let url = URL(string: UninstallPlan.accessibilitySettingsURL) { NSWorkspace.shared.open(url) }
            let hint = NSAlert()
            hint.messageText = "Remove Sweep from Accessibility"
            hint.informativeText = UninstallPlan.accessibilityHint
            hint.runModal()
            return true
        case .removeDefaults(let domain):
            UserDefaults.standard.removePersistentDomain(forName: domain)
            return true
        case .removeFolder(let path):
            guard FileManager.default.fileExists(atPath: path) else { return true }
            return (try? FileManager.default.removeItem(atPath: path)) != nil
        case .trashApp, .quit:
            return true   // handled in `run`
        }
    }
}
