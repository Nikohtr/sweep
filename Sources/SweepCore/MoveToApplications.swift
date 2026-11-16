import Foundation

/// At launch, offer to move Sweep into an Applications folder. Sweep asks; it never moves by itself.
/// A fixed place keeps updates and the Accessibility permission working.
public enum MoveToApplications {
    public enum Location: Sendable, Equatable {
        /// /Applications (or a folder in it) or ~/Applications.
        case applications
        /// macOS runs a quarantined download from a random read-only path (App Translocation).
        case translocated
        /// `swift run`, or `scripts/bundle.sh` output next to Package.swift.
        case devBuild
        /// Any other place, for example Downloads or a disk image.
        case elsewhere
    }

    public enum Step: Sendable, Equatable {
        case copy(from: String, to: String)
        /// Sweep was already allowed to open, so the copy must not be checked (or translocated) again.
        case removeQuarantine(String)
        /// Moves the item to the Trash (it can be put back).
        case trash(String)
        /// Open the new copy, then quit this one.
        case relaunch(String)
    }

    /// - Parameters:
    ///   - bundlePath: `Bundle.main.bundlePath`.
    ///   - packageManifestNearby: a `Package.swift` is in the folder above the app's folder (the repo's `build/`).
    public static func classify(bundlePath: String, homeDirectory: String, packageManifestNearby: Bool) -> Location {
        let path = normalize(bundlePath)
        guard path.hasSuffix(".app") else { return .devBuild }
        if path.contains("/AppTranslocation/"),
           path.hasPrefix("/private/var/folders/") || path.hasPrefix("/var/folders/") { return .translocated }
        let folders = ["/Applications", normalize(homeDirectory) + "/Applications"]
        if folders.contains(where: { path.hasPrefix($0 + "/") }) { return .applications }
        if packageManifestNearby, (path as NSString).deletingLastPathComponent.hasSuffix("/build") { return .devBuild }
        return .elsewhere
    }

    /// `debugFlag`: the `noMoveCheck` default (or `-noMoveCheck YES` at launch) is set.
    public static func shouldAsk(_ location: Location, dontAskAgain: Bool, debugFlag: Bool) -> Bool {
        guard !dontAskAgain, !debugFlag else { return false }
        return location == .elsewhere || location == .translocated
    }

    public static func destination(appName: String, homeDirectory: String, applicationsWritable: Bool) -> String {
        let folder = applicationsWritable ? "/Applications" : normalize(homeDirectory) + "/Applications"
        return folder + "/" + appName
    }

    public static func plan(source: String, destination: String, location: Location,
                            destinationExists: Bool) -> [Step] {
        var steps: [Step] = []
        if destinationExists { steps.append(.trash(destination)) }
        steps += [.copy(from: source, to: destination), .removeQuarantine(destination)]
        // A translocated path is not where the file really is; leave the original alone.
        if location != .translocated { steps.append(.trash(source)) }
        steps.append(.relaunch(destination))
        return steps
    }

    /// Shown when the move fails.
    public static func manualSteps(location: Location, sourceFolder: String) -> String {
        let from = location == .translocated
            ? "the folder you downloaded it to (for example Downloads)" : sourceFolder
        return "Quit Sweep. In Finder, drag Sweep from \(from) to Applications. Then open it from Applications."
    }

    private static func normalize(_ path: String) -> String {
        var p = (path as NSString).standardizingPath
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }
}
