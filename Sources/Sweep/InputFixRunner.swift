import Foundation
import IOKit.pwr_mgt
import SweepCore

/// Runs the `InputFix` steps. Sleeping the displays uses `pmset displaysleepnow`, which changes no setting.
@MainActor
enum InputFixRunner {
    static func run(_ steps: ArraySlice<InputFix.Step>, restartInput: @escaping @MainActor () -> Void) {
        guard let step = steps.first else { return }
        let rest = steps.dropFirst()
        switch step {
        case .sleepDisplays:
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            p.arguments = ["displaysleepnow"]
            try? p.run()
        case .wakeDisplays:
            var id: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Sweep input fix" as CFString, kIOPMUserActiveLocal, &id)
        case .restartInput:
            restartInput()
        case .wait(let seconds):
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                MainActor.assumeIsolated { run(rest, restartInput: restartInput) }
            }
            return
        }
        run(rest, restartInput: restartInput)
    }
}
