/// The per-app ignore list (bundle IDs). Gestures never start in these apps.
public enum IgnoreList {
    public static func add(_ id: String, to list: inout [String]) {
        if !list.contains(id) { list.append(id); list.sort() }
    }

    public static func toggle(_ id: String, in list: inout [String]) {
        if let i = list.firstIndex(of: id) { list.remove(at: i) } else { add(id, to: &list) }
    }

    public static func menuTitle(appName: String, ignored: Bool) -> String {
        ignored ? "Resume Sweep in \(appName)" : "Pause Sweep in \(appName)"
    }
}
