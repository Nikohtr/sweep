import AppKit
import ApplicationServices
import IOKit
import SweepCore

/// About › Copy Debug Info… and Report a Problem…. Reads facts only; the text is built by `DebugReport`.
@MainActor
enum DebugInfo {
    static func text(settings: SweepSettings, updatesOn: Bool) -> String {
        let info = Bundle.main.infoDictionary
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let input = DebugReport.Input(
            version: info?["CFBundleShortVersionString"] as? String,
            build: info?["CFBundleVersion"] as? String,
            macOS: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            arch: architecture, rosetta: underRosetta,
            location: MoveCheck.currentLocation(),
            accessibility: AXIsProcessTrusted(),
            launchAtLogin: LoginItemPlan.isOn(LoginItem.status),
            updates: updatesOn,
            devices: inputDevices(),
            checks: Diagnostics.report(DiagnosticsReader.read()),
            settings: settings)
        return DebugReport.text(input, homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
                                userName: NSUserName())
    }

    /// Shows the full text first; it goes to the clipboard only when the user clicks Copy.
    static func showAndCopy(settings: SweepSettings, updatesOn: Bool) {
        let report = text(settings: settings, updatesOn: updatesOn)
        let alert = NSAlert()
        alert.messageText = "Debug Info"
        alert.informativeText = "This text is copied when you click Copy. Paste it into your problem report."
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 460, height: 280)
        if let view = scroll.documentView as? NSTextView {
            view.string = report
            view.isEditable = false
            view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    static func reportProblem() {
        if let url = URL(string: DebugReport.issuesURL) { NSWorkspace.shared.open(url) }
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    private static var underRosetta: Bool {
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0) == 0 && translated == 1
    }

    /// Kinds of pointing devices from the I/O Registry (HID "Product" names; no permission needed).
    private static func inputDevices() -> [InputDeviceKind] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator)
                == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var kinds: [InputDeviceKind] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            if let kind = InputDeviceKind(product: property("Product") as? String ?? "",
                                          vendorID: property("VendorID") as? Int,
                                          productID: property("ProductID") as? Int) {
                kinds.append(kind)
            }
        }
        return kinds
    }
}
