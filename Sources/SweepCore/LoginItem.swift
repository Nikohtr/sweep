/// Login item state, mirrored from the system (ServiceManagement) so the rules can be tested.
public enum LoginItemStatus: Sendable, Equatable {
    case notRegistered, enabled, requiresApproval, notFound
}

/// What to do when the user flips "Launch at login".
public enum LoginItemPlan {
    public enum Action: Sendable, Equatable { case register, unregister, none }

    public static func action(wanted: Bool, current: LoginItemStatus) -> Action {
        switch (wanted, current) {
        case (true, .notRegistered), (true, .notFound): return .register
        case (false, .enabled), (false, .requiresApproval): return .unregister
        default: return .none
        }
    }

    /// The toggle shows "on" when macOS has the item, even if it still waits for approval.
    public static func isOn(_ status: LoginItemStatus) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    public static func message(for status: LoginItemStatus) -> String? {
        status == .requiresApproval
            ? "Allow Sweep in System Settings › General › Login Items to finish."
            : nil
    }
}
