/// Decides whether a gesture may start, from the hit test and the held modifier keys.
public enum GestureGate {
    public static func origin(hit: HitInfo, held: ModifierKeys, settings: SweepSettings) -> Origin? {
        guard settings.gesturesEnabled else { return nil }
        if let app = hit.appBundleID, settings.ignoredApps.contains(app) { return nil }
        let roles = ModifierResolver.roles(held: held, settings: settings)
        let superHeld = roles.contains(.superKey)
        // "Require for all gestures": nothing starts without the super modifier.
        if settings.requireSuperModifier, !superHeld { return nil }
        let origin = OriginClassifier.classify(hit, superModifier: superHeld)
        if origin == .appMenu, !settings.appMenuGestures { return nil }
        if origin == .missionControl || origin == .missionControlSpace, !settings.missionControlGestures { return nil }
        if origin == .tab, settings.disabledTabApps.contains(TabApp.of(bundleID: hit.appBundleID)) { return .titlebar }
        return origin
    }
}
