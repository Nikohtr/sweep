import Testing
@testable import SweepCore

/// The diagnostics check that the system settings the gestures need are on.
@Suite struct DiagnosticsTests {
    private let allOn = DiagnosticInput(pinchToZoom: true, smartZoom: true, haptics: true, spaceShortcuts: true)

    @Test func allOnPasses() {
        let items = Diagnostics.report(allOn)
        #expect(items.count == 4)
        #expect(items.allSatisfy { $0.status == .ok })
        #expect(Diagnostics.summary(items) == "All checks passed.")
    }

    @Test func orderIsFixed() {
        #expect(Diagnostics.report(allOn).map(\.name) == ["Pinch to zoom", "Smart zoom", "Haptic feedback",
                                                           "Mission Control shortcuts"])
    }

    @Test func offIsAProblemWithAHint() {
        var input = allOn
        input.smartZoom = false
        let item = Diagnostics.report(input)[1]
        #expect(item.status == .problem)
        #expect(item.hint.contains("Trackpad"))
        #expect(Diagnostics.summary(Diagnostics.report(input)) == "1 problem found.")
    }

    @Test func unknownIsNotAProblem() {
        let items = Diagnostics.report(DiagnosticInput(pinchToZoom: nil, smartZoom: false, haptics: false,
                                                       spaceShortcuts: nil))
        #expect(items[0].status == .unknown)
        #expect(Diagnostics.summary(items) == "2 problems found.")
    }

    @Test func textLinesShowEachItem() {
        var input = allOn
        input.haptics = false
        let text = Diagnostics.text(Diagnostics.report(input))
        #expect(text.contains("✓ Pinch to zoom"))
        #expect(text.contains("✗ Haptic feedback"))
    }
}
