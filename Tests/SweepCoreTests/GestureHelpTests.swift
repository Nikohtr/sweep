import Testing
@testable import SweepCore

/// The Menubar tab lists the menu bar gestures. Each row must match what the app really does.
@Suite struct GestureHelpTests {
    @Test func everyMenubarRowMapsToAnAction() {
        for row in GestureHelp.menubar {
            let roles: Set<ModifierRole> = row.role.map { [$0] } ?? []
            #expect(MenubarActions.finalAction(for: row.steps, roles: roles) != nil, "\(row.gesture)")
        }
    }

    @Test func rowsCoverEveryMenubarActionKind() {
        let actions = GestureHelp.menubar.compactMap { row -> MenubarAction? in
            MenubarActions.finalAction(for: row.steps, roles: row.role.map { [$0] } ?? [])
        }
        #expect(actions.contains(.unsnapAll(allScreens: false)))
        #expect(actions.contains(.unsnapAll(allScreens: true)))
        #expect(actions.contains(.minimizeAll(allScreens: false)))
        #expect(actions.contains(.unminimizeAll(allScreens: false)))
        #expect(actions.contains(.moveSnappedToScreen(.right)))
        #expect(actions.contains(.switchApp(forward: true)))
    }

    @Test func rowTextIsNeverEmpty() {
        #expect(!GestureHelp.menubar.isEmpty)
        for row in GestureHelp.menubar {
            #expect(!row.gesture.isEmpty && !row.action.isEmpty)
        }
    }

    @Test func modifierLabelUsesTheSettings() {
        var s = SweepSettings()
        s.setKeys([.option, .shift], for: .screen)
        #expect(GestureHelp.modifierLabel(.screen, settings: s) == "Display (⌥⇧)")
    }

    /// Sweep's own role names, by what each role does (branding spec 2026-11-16).
    @Test func roleNamesAreSweepsOwn() {
        #expect(GestureHelp.roleName(.general) == "Action")
        #expect(GestureHelp.roleName(.secondary) == "Extend")
        #expect(GestureHelp.roleName(.tertiary) == "Fine")
        #expect(GestureHelp.roleName(.screen) == "Display")
        #expect(GestureHelp.roleName(.superKey) == "Anywhere")
        #expect(ModifierRole.allCases.allSatisfy { !GestureHelp.roleNote($0).isEmpty })
    }

    @Test func userTextNeverUsesTheOldRoleWords() {
        let old = ["general modifier", "secondary", "tertiary", "super modifier", "screen modifier"]
        let texts = GestureKind.allCases.map(\.title) + Tutorial.pages.map(\.body)
            + ModifierRole.allCases.map(GestureHelp.roleNote)
        for text in texts {
            #expect(!old.contains { text.lowercased().contains($0) }, "\(text)")
        }
    }
}
