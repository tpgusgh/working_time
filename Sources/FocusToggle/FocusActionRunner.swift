import Foundation

struct FocusActionRunner {
    @discardableResult
    static func run(_ action: FocusAction) -> Bool {
        var allSucceeded = true
        for command in action.commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    allSucceeded = false
                }
            } catch {
                allSucceeded = false
            }
        }
        return allSucceeded
    }
}
