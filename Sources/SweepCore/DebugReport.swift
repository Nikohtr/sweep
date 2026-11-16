import Foundation

/// Kinds of pointing devices. Only the kind goes into a report, never the device's own name
/// (a Bluetooth name can hold the owner's name).
public enum InputDeviceKind: String, Sendable, CaseIterable, Comparable {
    case builtInTrackpad = "Built-in trackpad"
    case magicTrackpad = "Magic Trackpad"
    case magicMouse = "Magic Mouse"
    case otherMouse = "Other mouse"

    /// Apple's vendor IDs: Bluetooth (0x004C) and USB (0x05AC).
    static let appleVendors: Set<Int> = [0x004C, 0x05AC]
    static let magicMouseIDs: Set<Int> = [0x030D, 0x0269]
    static let magicTrackpadIDs: Set<Int> = [0x030E, 0x0265]

    /// From the HID vendor and product IDs first (a Magic Mouse can carry its owner's name, for example
    /// "Alex's Mouse"), then from the "Product" string. Nil for keyboards and other devices.
    public init?(product: String, vendorID: Int? = nil, productID: Int? = nil) {
        if let v = vendorID, let id = productID, Self.appleVendors.contains(v) {
            if Self.magicMouseIDs.contains(id) { self = .magicMouse; return }
            if Self.magicTrackpadIDs.contains(id) { self = .magicTrackpad; return }
        }
        let p = product.lowercased()
        if p.contains("magic trackpad") { self = .magicTrackpad }
        else if p.contains("magic mouse") { self = .magicMouse }
        else if p.contains("trackpad") { self = .builtInTrackpad }
        else if p.contains("mouse") { self = .otherMouse }
        else { return nil }
    }

    public static func < (a: Self, b: Self) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// The text for "Copy Debug Info". The user sees all of it before it is copied.
/// It has no window titles, no ignored-app IDs (only their count), and no user paths, user name or email.
public enum DebugReport {
    public static let issuesURL = "https://github.com/Nikohtr/sweep/issues/new"

    public struct Input: Sendable {
        public var version: String?
        public var build: String?
        public var macOS: String
        public var arch: String
        public var rosetta: Bool
        public var location: MoveToApplications.Location
        public var accessibility: Bool
        public var launchAtLogin: Bool
        public var updates: Bool
        public var devices: [InputDeviceKind]
        public var checks: [DiagnosticItem]
        public var settings: SweepSettings

        public init(version: String?, build: String?, macOS: String, arch: String, rosetta: Bool,
                    location: MoveToApplications.Location, accessibility: Bool, launchAtLogin: Bool,
                    updates: Bool, devices: [InputDeviceKind], checks: [DiagnosticItem], settings: SweepSettings) {
            self.version = version; self.build = build; self.macOS = macOS; self.arch = arch
            self.rosetta = rosetta; self.location = location; self.accessibility = accessibility
            self.launchAtLogin = launchAtLogin; self.updates = updates; self.devices = devices
            self.checks = checks; self.settings = settings
        }
    }

    public static func text(_ i: Input, homeDirectory: String, userName: String) -> String {
        let devices: [String] = Array(Set(i.devices)).sorted().map(\.rawValue)
        let version: String = AppVersion.display(short: i.version, build: i.build)
            .replacingOccurrences(of: "Version ", with: "")
        let system: String = "macOS \(i.macOS), \(i.arch)" + (i.rosetta ? " (Rosetta)" : "")
        let deviceLine: String = devices.isEmpty ? "none found" : devices.joined(separator: ", ")
        var lines: [String] = ["Sweep " + version, system, "Runs from: " + place(i.location)]
        lines.append("Accessibility: " + (i.accessibility ? "allowed" : "not allowed"))
        lines.append("Launch at login: " + (i.launchAtLogin ? "on" : "off"))
        lines.append("Updates: " + (i.updates ? "on" : "off"))
        lines.append("Input devices: " + deviceLine)
        lines += ["", "System checks:", Diagnostics.text(i.checks), "", "Settings:", settingsJSON(i.settings)]
        return scrub(lines.joined(separator: "\n"), homeDirectory: homeDirectory, userName: userName)
    }

    /// Replaces the home folder with "~", the user name with "<user>" and email addresses with "<email>".
    public static func scrub(_ text: String, homeDirectory: String, userName: String) -> String {
        var t = text
        if homeDirectory.count > 1 { t = t.replacingOccurrences(of: homeDirectory, with: "~") }
        t = t.replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, with: "<email>",
                                   options: .regularExpression)
        if userName.count >= 3 {
            t = t.replacingOccurrences(of: #"\b\#(NSRegularExpression.escapedPattern(for: userName))\b"#,
                                       with: "<user>", options: [.regularExpression, .caseInsensitive])
        }
        return t
    }

    private static func place(_ location: MoveToApplications.Location) -> String {
        switch location {
        case .applications: return "Applications"
        case .translocated: return "a temporary copy (App Translocation)"
        case .devBuild: return "a development build"
        case .elsewhere: return "outside Applications"
        }
    }

    private static func settingsJSON(_ settings: SweepSettings) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "(could not read)"
        }
        object["ignoredApps"] = settings.ignoredApps.count
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        else { return "(could not read)" }
        return String(decoding: out, as: UTF8.self)
    }
}
