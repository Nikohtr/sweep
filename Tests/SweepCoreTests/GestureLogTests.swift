import Testing
@testable import SweepCore

@Suite struct GestureLogTests {
    @Test func subsystemIsTheBundleID() {
        #expect(SweepLog.subsystem == "io.github.nikohtr.sweep")
        #expect(SweepLog.gestureCategory == "gesture")
        #expect(SweepLog.appCategory == "app")
    }

    @Test func streamCommandShowsDebugLinesOfSweepOnly() {
        #expect(SweepLog.streamCommand
            == "log stream --style compact --level debug --predicate 'subsystem == \"io.github.nikohtr.sweep\"'")
    }

    @Test func placeNamesOriginAndRoles() {
        #expect(SweepLog.place(origin: nil, roles: []) == "")
        #expect(SweepLog.place(origin: "titlebar", roles: []) == " on titlebar")
        #expect(SweepLog.place(origin: "window", roles: ["secondary", "superKey"]) == " on window [secondary+superKey]")
    }

    @Test func endedLineListsSteps() {
        #expect(SweepLog.ended(place: " on dock", steps: ["pinchIn"]) == "Sweep gesture on dock: pinchIn")
        #expect(SweepLog.ended(place: "", steps: ["swipe(right)", "pause", "swipe(right)"])
            == "Sweep gesture: swipe(right), pause, swipe(right)")
        #expect(SweepLog.ended(place: " on titlebar", steps: []) == "Sweep gesture on titlebar: none")
    }

    @Test func otherLines() {
        #expect(SweepLog.cancelled(place: " on titlebar") == "Sweep gesture on titlebar: cancelled")
        #expect(SweepLog.step("swipe(left)") == "Sweep gesture step: swipe(left)")
        #expect(SweepLog.dropped == "Sweep gesture: dropped (the app under the cursor did not answer)")
    }
}
