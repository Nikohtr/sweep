import Foundation

/// The licenses Sweep ships. Each one is a text file in `Sweep.app/Contents/Resources`
/// (`scripts/bundle.sh` copies them), and About opens them.
public struct LicenseNotice: Equatable, Sendable {
    public let component: String
    public let license: String
    /// File name in the app's Resources folder.
    public let resourceFile: String

    public static let sweep = LicenseNotice(component: "Sweep", license: "GPL-3.0", resourceFile: "LICENSE.txt")
    public static let sparkle = LicenseNotice(component: "Sparkle", license: "MIT",
                                              resourceFile: "Sparkle-LICENSE.txt")

    /// Sweep first, then every bundled dependency.
    public static let all: [LicenseNotice] = [sweep, sparkle]

    /// The one-line license note under the About text.
    public static var aboutLine: String {
        let deps = all.dropFirst().map { "\($0.component) (\($0.license) license)" }.joined(separator: ", ")
        return "\(sweep.component) is free software under the \(sweep.license) license. It uses \(deps)."
    }
}
