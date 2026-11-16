import Foundation

/// Settings export and import as a JSON file:
/// `{"app": "Sweep", "formatVersion": "1.0", "settings": {…every setting, ignore list included…}}`.
/// Import ignores unknown keys, rejects a newer major format, and changes nothing when the file is bad.
public enum SettingsFile {
    /// MAJOR.MINOR. Raise MINOR for added keys (older versions ignore them); raise MAJOR only when an older
    /// version would read the file wrongly.
    public static let formatVersion = "1.0"
    public static let suggestedName = "Sweep Settings.json"

    public enum ImportError: Error, Equatable {
        case notASettingsFile
        case newerFormat(String)
        case badSettings

        public var message: String {
            switch self {
            case .notASettingsFile: return "This is not a Sweep settings file."
            case .newerFormat(let v):
                return "This file is from a newer version of Sweep (format \(v)). Update Sweep, then try again."
            case .badSettings: return "This settings file is damaged. Nothing was changed."
            }
        }
    }

    public static func export(_ settings: SweepSettings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Envelope(app: "Sweep", formatVersion: formatVersion, settings: settings))
    }

    /// The settings in `data`. This Mac keeps its own tutorial state (an import does not show the Welcome again)
    /// and its login item state (that one mirrors macOS, which an import does not change).
    public static func imported(_ data: Data, current: SweepSettings) throws -> SweepSettings {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["app"] as? String == "Sweep",
              let version = object["formatVersion"] as? String,
              let major = majorVersion(version),
              let settingsObject = object["settings"] as? [String: Any] else { throw ImportError.notASettingsFile }
        guard let ownMajor = majorVersion(formatVersion), major <= ownMajor else {
            throw ImportError.newerFormat(version)
        }
        guard let settingsData = try? JSONSerialization.data(withJSONObject: settingsObject),
              var settings = try? JSONDecoder().decode(SweepSettings.self, from: settingsData) else {
            throw ImportError.badSettings
        }
        settings.tutorialSeen = current.tutorialSeen
        settings.launchAtLogin = current.launchAtLogin
        return settings.clamped()
    }

    private static func majorVersion(_ version: String) -> Int? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        return Int(parts[0])
    }

    private struct Envelope: Encodable {
        let app: String
        let formatVersion: String
        let settings: SweepSettings
    }
}
