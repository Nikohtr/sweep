import AppKit
import SweepCore

/// At launch, ask to move Sweep into Applications (rules: `MoveToApplications` in SweepCore).
@MainActor
enum MoveCheck {
    /// Set by "Don't ask again".
    static let dontAskKey = "moveCheck.dontAsk"
    /// Debug flag: `defaults write <bundle id> noMoveCheck -bool YES`, or launch with `-noMoveCheck YES`.
    static let debugKey = "noMoveCheck"

    /// Returns true when Sweep is relaunching from the new place (the caller stops its launch work).
    /// Where this copy of Sweep runs from.
    static func currentLocation() -> MoveToApplications.Location {
        let bundlePath = Bundle.main.bundlePath
        let repoFolder = ((bundlePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
        return MoveToApplications.classify(
            bundlePath: bundlePath, homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            packageManifestNearby: FileManager.default.fileExists(atPath: repoFolder + "/Package.swift"))
    }

    static func runAtLaunch(defaults: UserDefaults = .standard) -> Bool {
        let fm = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        let home = fm.homeDirectoryForCurrentUser.path
        let location = currentLocation()
        guard MoveToApplications.shouldAsk(location, dontAskAgain: defaults.bool(forKey: dontAskKey),
                                           debugFlag: defaults.bool(forKey: debugKey)) else { return false }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move Sweep to Applications?"
        alert.informativeText = "Sweep works best from the Applications folder. "
            + "There, updates install and the Accessibility permission stays in place."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        let answer = alert.runModal()
        if alert.suppressionButton?.state == .on { defaults.set(true, forKey: dontAskKey) }
        guard answer == .alertFirstButtonReturn else { return false }

        let destination = MoveToApplications.destination(
            appName: (bundlePath as NSString).lastPathComponent, homeDirectory: home,
            applicationsWritable: fm.isWritableFile(atPath: "/Applications"))
        let steps = MoveToApplications.plan(source: bundlePath, destination: destination, location: location,
                                            destinationExists: fm.fileExists(atPath: destination))
        do {
            for step in steps { try run(step) }
            return true
        } catch {
            let failed = NSAlert()
            failed.alertStyle = .warning
            failed.messageText = "Sweep could not move itself"
            let folder = ((bundlePath as NSString).deletingLastPathComponent as NSString).lastPathComponent
            failed.informativeText = MoveToApplications.manualSteps(location: location, sourceFolder: folder)
                + "\n\n(\(error.localizedDescription))"
            failed.runModal()
            return false
        }
    }

    private static func run(_ step: MoveToApplications.Step) throws {
        let fm = FileManager.default
        switch step {
        case .copy(let from, let to):
            try fm.createDirectory(atPath: (to as NSString).deletingLastPathComponent,
                                   withIntermediateDirectories: true)
            try fm.copyItem(atPath: from, toPath: to)
        case .removeQuarantine(let path):
            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-d", "-r", "com.apple.quarantine", path]
            try xattr.run()
            xattr.waitUntilExit()   // a copy with no quarantine flag exits non-zero: that is fine
        case .trash(let path):
            try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        case .relaunch(let path):
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config) { _, error in
                DispatchQueue.main.async {
                    if error != nil {
                        let alert = NSAlert()
                        alert.messageText = "Sweep is now in Applications"
                        alert.informativeText = "Open Sweep from the Applications folder."
                        alert.runModal()
                    }
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
