import AppKit
import ApplicationServices
import SweepCore

/// Runs `PermissionFlow` against the real Accessibility trust state.
@MainActor
final class PermissionController: ObservableObject {
    var onStartInput: (() -> Void)?
    var onStopInput: (() -> Void)?
    var onStatusChange: ((PermissionFlow.Status) -> Void)?

    private var flow: PermissionFlow
    private var recheck: DispatchWorkItem?

    /// Published so the Welcome window's permission page updates by itself.
    @Published private(set) var status: PermissionFlow.Status = .unknown

    /// `promptAtLaunch: false` when the Welcome window will ask instead of the system dialog.
    init(promptAtLaunch: Bool = true) { flow = PermissionFlow(promptAtLaunch: promptAtLaunch) }

    func begin() { check() }

    func requestFromUser() { run(flow.userRequested()) }

    private func check() {
        let before = flow.status
        run(flow.update(trusted: AXIsProcessTrusted()))
        status = flow.status
        if flow.status != before { onStatusChange?(flow.status) }
    }

    private func run(_ actions: [PermissionFlow.Action]) {
        for action in actions {
            switch action {
            case .promptSystem:
                // Shows the system "would like to control this computer" dialog once.
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            case .openSettings:
                let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                if let u = URL(string: url) { NSWorkspace.shared.open(u) }
            case .startInput:
                onStartInput?()
            case .stopInput:
                onStopInput?()
            case .recheck(let seconds):
                recheck?.cancel()
                let item = DispatchWorkItem { [weak self] in
                    MainActor.assumeIsolated { self?.check() }
                }
                recheck = item
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
            }
        }
    }
}
