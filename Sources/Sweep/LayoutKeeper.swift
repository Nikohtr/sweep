import AppKit
import ApplicationServices
import SweepCore

/// Keeps a rolling snapshot of every window's frame per display set, and after a display
/// change puts windows back where they were the last time that display set was connected.
@MainActor
final class LayoutKeeper {
    private var memory = LayoutMemory<WindowKey>()
    private var timer: Timer?
    private var pendingRestore: DispatchWorkItem?
    private let settings: () -> SweepSettings
    /// Seconds between snapshots.
    static let snapshotInterval: TimeInterval = 5

    init(settings: @escaping () -> SweepSettings) {
        self.settings = settings
    }

    func start() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        snapshot()
        timer = Timer.scheduledTimer(withTimeInterval: Self.snapshotInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                // No snapshots while a restore waits: the moved layout must not overwrite the saved one.
                if self?.pendingRestore == nil { self?.snapshot() }
            }
        }
    }

    private func signature() -> DisplaySignature {
        DisplaySignature(screens: AXHitTester.screens().map(\.frame))
    }

    private func currentFrames() -> [WindowKey: CGRect] {
        var frames: [WindowKey: CGRect] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            for window in AppWindows.windows(of: app) where !AppWindows.isMinimized(window) {
                if let f = AXHitTester.frame(window) { frames[WindowKey(element: window)] = f }
            }
        }
        return frames
    }

    private func snapshot() {
        guard AXIsProcessTrusted() else { return }
        memory.record(signature: signature(), frames: currentFrames())
    }

    private func screensChanged() {
        pendingRestore?.cancel()
        pendingRestore = nil
        guard let delay = LayoutMemory<WindowKey>.restoreDelay(settings: settings()) else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.restore() }
        }
        pendingRestore = work
        // Wait for macOS to finish moving windows to the new display set first.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func restore() {
        pendingRestore = nil
        guard AXIsProcessTrusted() else { return }
        let plan = memory.restorePlan(signature: signature(), current: currentFrames(),
                                      timeoutSeconds: settings().externalDisplayTimeout)
        for (key, frame) in plan { WindowMover.setFrame(frame, of: key.element) }
        snapshot()
    }
}
