import AppKit
import SweepCore

/// Reads (never writes) the system settings that `Diagnostics` checks.
@MainActor
enum DiagnosticsReader {
    private static let trackpadDomains = ["com.apple.AppleMultitouchTrackpad",
                                          "com.apple.driver.AppleBluetoothMultitouch.trackpad"]

    static func read() -> DiagnosticInput {
        DiagnosticInput(pinchToZoom: trackpadFlag("TrackpadPinch"),
                        smartZoom: trackpadFlag("TrackpadTwoFingerDoubleTapGesture"),
                        haptics: trackpadFlag("ActuateDetents"),
                        spaceShortcuts: spaceShortcutsOn())
    }

    /// The built-in trackpad's value, or the Magic Trackpad's; nil when neither is stored.
    private static func trackpadFlag(_ key: String) -> Bool? {
        for domain in trackpadDomains {
            if let n = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber {
                return n.intValue != 0
            }
        }
        return nil
    }

    /// Mission Control "Move left a space" (79) and "Move right a space" (81). Nil when not stored.
    private static func spaceShortcutsOn() -> Bool? {
        guard let all = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                                                  "com.apple.symbolichotkeys" as CFString) as? [String: Any] else {
            return nil
        }
        let flags = ["79", "81"].compactMap { (all[$0] as? [String: Any])?["enabled"] as? Bool }
        return flags.isEmpty ? nil : flags.allSatisfy { $0 }
    }

    static func showReport() {
        let items = Diagnostics.report(read())
        let alert = NSAlert()
        alert.messageText = Diagnostics.summary(items)
        alert.informativeText = Diagnostics.text(items)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
