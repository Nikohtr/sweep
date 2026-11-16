import ServiceManagement
import SweepCore

/// Talks to ServiceManagement for "Launch at login".
@MainActor
enum LoginItem {
    static var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        default: return .notRegistered
        }
    }

    /// Applies the user's wish. Returns an error text if macOS refused.
    @discardableResult
    static func set(_ wanted: Bool) -> String? {
        do {
            switch LoginItemPlan.action(wanted: wanted, current: status) {
            case .register: try SMAppService.mainApp.register()
            case .unregister: try SMAppService.mainApp.unregister()
            case .none: break
            }
            return nil
        } catch {
            return "Could not change the login item: \(error.localizedDescription)"
        }
    }
}
