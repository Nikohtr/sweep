import Foundation
import Testing
@testable import SweepCore

@Suite struct DebugReportTests {
    func input(devices: [InputDeviceKind] = [.builtInTrackpad], settings: SweepSettings = SweepSettings())
        -> DebugReport.Input {
        DebugReport.Input(version: "1.0.0", build: "212", macOS: "14.5.0", arch: "arm64", rosetta: false,
                          location: .applications, accessibility: true, launchAtLogin: false, updates: true,
                          devices: devices,
                          checks: [DiagnosticItem(name: "Pinch to zoom", status: .ok, hint: "")],
                          settings: settings)
    }

    @Test func headerLines() {
        let text = DebugReport.text(input(), homeDirectory: "/Users/alex", userName: "alex")
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "Sweep 1.0.0 (212)")
        #expect(lines[1] == "macOS 14.5.0, arm64")
        #expect(lines.contains("Runs from: Applications"))
        #expect(lines.contains("Accessibility: allowed"))
        #expect(lines.contains("Launch at login: off"))
        #expect(lines.contains("Updates: on"))
        #expect(lines.contains("Input devices: Built-in trackpad"))
        #expect(lines.contains("✓ Pinch to zoom"))
    }

    @Test func rosettaAndNoDevices() {
        var i = input(devices: [])
        i.rosetta = true
        i.arch = "x86_64"
        let text = DebugReport.text(i, homeDirectory: "/Users/alex", userName: "alex")
        #expect(text.contains("macOS 14.5.0, x86_64 (Rosetta)"))
        #expect(text.contains("Input devices: none found"))
    }

    @Test func devicesAreSortedAndUnique() {
        let text = DebugReport.text(input(devices: [.magicMouse, .builtInTrackpad, .magicMouse]),
                                    homeDirectory: "/Users/alex", userName: "alex")
        #expect(text.contains("Input devices: Built-in trackpad, Magic Mouse"))
    }

    @Test func settingsAreIncludedButIgnoredAppsOnlyAsACount() {
        var s = SweepSettings()
        s.ignoredApps = ["com.example.secret", "com.example.other"]
        let text = DebugReport.text(input(settings: s), homeDirectory: "/Users/alex", userName: "alex")
        #expect(text.contains("\"ignoredApps\" : 2"))
        #expect(!text.contains("com.example.secret"))
        #expect(text.contains("Settings:"))
    }

    @Test func scrubRemovesPathsUserNameAndEmail() {
        let raw = "at /Users/alex/Downloads/Sweep.app by alex, mail alex.smith@example.com"
        #expect(DebugReport.scrub(raw, homeDirectory: "/Users/alex", userName: "alex")
            == "at ~/Downloads/Sweep.app by <user>, mail <email>")
    }

    @Test func scrubSkipsVeryShortUserNames() {
        // A two-letter name would also match inside ordinary words.
        #expect(DebugReport.scrub("all on", homeDirectory: "/Users/al", userName: "al") == "all on")
    }

    @Test func classifiesInputDevicesWithoutKeepingTheirNames() {
        #expect(InputDeviceKind(product: "Apple Internal Keyboard / Trackpad") == .builtInTrackpad)
        #expect(InputDeviceKind(product: "Magic Trackpad") == .magicTrackpad)
        #expect(InputDeviceKind(product: "Magic Trackpad 2") == .magicTrackpad)
        #expect(InputDeviceKind(product: "Magic Mouse") == .magicMouse)
        #expect(InputDeviceKind(product: "USB Optical Mouse") == .otherMouse)
        #expect(InputDeviceKind(product: "Apple Internal Keyboard") == nil)
        #expect(InputDeviceKind(product: "") == nil)
    }

    @Test func renamedAppleDevicesAreFoundByTheirIDs() {
        // Bluetooth Magic Mouse 2 named after its owner.
        #expect(InputDeviceKind(product: "Alex's Mouse", vendorID: 0x004C, productID: 0x0269) == .magicMouse)
        #expect(InputDeviceKind(product: "Alex's Trackpad", vendorID: 0x004C, productID: 0x0265) == .magicTrackpad)
        #expect(InputDeviceKind(product: "Magic Trackpad", vendorID: 0x05AC, productID: 0x030E) == .magicTrackpad)
        // Unknown IDs fall back to the name; other vendors never count as Magic devices.
        #expect(InputDeviceKind(product: "Alex's Mouse", vendorID: 0x046D, productID: 0x0269) == .otherMouse)
        #expect(InputDeviceKind(product: "Apple Internal Keyboard / Trackpad", vendorID: nil, productID: nil)
            == .builtInTrackpad)
    }

    @Test func reportAProblemGoesToGitHubIssues() {
        #expect(DebugReport.issuesURL == "https://github.com/Nikohtr/sweep/issues/new")
    }
}
