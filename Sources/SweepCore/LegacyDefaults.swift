/// Settings saved under Sweep's old bundle ID, copied once to the new ID.
public enum LegacyDefaults {
    /// The bundle ID Sweep used before its first public release.
    public static let oldDomain = "local.sweep.app"
    /// The defaults keys that Sweep itself writes.
    public static let keys: Set<String> = ["settings.v1"]

    /// Sweep's keys that are in the old domain and not yet in the new one.
    /// Settings already saved under the new ID always win.
    public static func keysToCopy(old: Set<String>, new: Set<String>) -> Set<String> {
        old.intersection(keys).subtracting(new)
    }
}
