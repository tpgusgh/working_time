import Foundation

struct FocusActionRunner {
    static func run(_ action: FocusAction) {
        for command in action.commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            try? process.run()
            process.waitUntilExit()
        }
    }
}
