import AppKit
import SweepCore
import UniformTypeIdentifiers

/// Export Settings… / Import Settings… (file format and rules: `SettingsFile` in SweepCore).
@MainActor
enum SettingsTransfer {
    static func export(_ store: SettingsStore) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = SettingsFile.suggestedName
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsFile.export(store.settings).write(to: url, options: .atomic)
        } catch {
            fail("Sweep could not save the settings.", error.localizedDescription)
        }
    }

    /// A bad file shows an error and changes nothing.
    static func importFile(into store: SettingsStore) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            store.settings = try SettingsFile.imported(data, current: store.settings)
        } catch let error as SettingsFile.ImportError {
            fail("Sweep could not import the settings.", error.message)
        } catch {
            fail("Sweep could not import the settings.", error.localizedDescription)
        }
    }

    private static func fail(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}
