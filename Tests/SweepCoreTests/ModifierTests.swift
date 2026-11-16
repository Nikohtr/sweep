import Foundation
import Testing
@testable import SweepCore

@Suite struct ModifierTests {
    private let s = SweepSettings()

    @Test func defaults() {
        #expect(s.keys(for: .general) == [.control])
        #expect(s.keys(for: .screen) == [.option])
        #expect(s.keys(for: .secondary) == [.shift])
        #expect(s.keys(for: .tertiary) == [.control, .shift])
        #expect(s.keys(for: .superKey) == [.command])
    }

    @Test func noKeysNoRoles() {
        #expect(ModifierResolver.roles(held: [], settings: s).isEmpty)
    }

    @Test func exactMatchPicksOneRole() {
        #expect(ModifierResolver.roles(held: [.control], settings: s) == [.general])
        #expect(ModifierResolver.roles(held: [.option], settings: s) == [.screen])
        #expect(ModifierResolver.roles(held: [.shift], settings: s) == [.secondary])
    }

    @Test func tertiaryIsNotAlsoGeneralOrSecondary() {
        #expect(ModifierResolver.roles(held: [.control, .shift], settings: s) == [.tertiary])
    }

    @Test func superCombinesWithAnyRole() {
        #expect(ModifierResolver.roles(held: [.command], settings: s) == [.superKey])
        #expect(ModifierResolver.roles(held: [.command, .shift], settings: s) == [.superKey, .secondary])
        #expect(ModifierResolver.roles(held: [.command, .control, .shift], settings: s) == [.superKey, .tertiary])
    }

    @Test func unknownComboHasNoRole() {
        #expect(ModifierResolver.roles(held: [.option, .shift], settings: s).isEmpty)
    }

    @Test func emptyRoleNeverMatches() {
        var c = s
        c.setKeys([], for: .screen)
        #expect(!ModifierResolver.roles(held: [], settings: c).contains(.screen))
        #expect(ModifierResolver.roles(held: [.option], settings: c).isEmpty)
    }

    @Test func customKeysAndReset() {
        var c = s
        c.setKeys([.option, .command], for: .general)
        #expect(ModifierResolver.roles(held: [.option, .command], settings: c).contains(.general))
        c.resetModifiers()
        #expect(c.keys(for: .general) == [.control])
        #expect(c == s)
    }

    @Test func symbolsReadInMacOrder() {
        #expect(ModifierKeys([.command, .shift, .control, .option]).symbols == "⌃⌥⇧⌘")
        #expect(ModifierKeys().symbols == "none")
    }

    @Test func modifiersSurviveJSON() throws {
        var c = s
        c.setKeys([.option, .shift], for: .tertiary)
        let back = try JSONDecoder().decode(SweepSettings.self, from: JSONEncoder().encode(c))
        #expect(back.keys(for: .tertiary) == [.option, .shift])
    }
}
