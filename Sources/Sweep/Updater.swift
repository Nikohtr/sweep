import AppKit
import Sparkle
import SweepCore

/// In-app updates with Sparkle. Off in builds without an update key (see `UpdatePolicy.isEnabled`).
/// A scheduled check that finds an update shows a menu row and an icon badge
/// (`pendingVersion`) instead of a window, while the menu bar icon is visible.
@MainActor
final class Updater: NSObject, ObservableObject {
    let isEnabled: Bool
    /// The version of an update that waits for the user, shown as a menu row and badge.
    @Published private(set) var pendingVersion: String? {
        didSet { onPendingChange?(pendingVersion) }
    }
    /// Set by the app delegate: whether the menu bar icon is visible now.
    var iconVisible: () -> Bool = { true }
    var onPendingChange: ((String?) -> Void)?
    private var controller: SPUStandardUpdaterController?

    override init() {
        let info = Bundle.main.infoDictionary
        isEnabled = UpdatePolicy.isEnabled(publicKey: info?["SUPublicEDKey"] as? String,
                                           feedURL: info?["SUFeedURL"] as? String)
        super.init()
        if isEnabled {
            controller = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        }
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { objectWillChange.send(); controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloads: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { objectWillChange.send(); controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Shows Sparkle's window: a fresh check, or the update that waits.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }
}

extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus || !UpdatePolicy.useGentleReminder(iconVisible: iconVisible())
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        if !handleShowingUpdate { pendingVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingVersion = nil
    }
}
