import XCTest
@testable import FocusToggle

final class FocusActionTests: XCTestCase {
    func test_turnOnCommands() {
        let commands = FocusAction.turnOn.commands
        XCTAssertEqual(commands, [
            ["/usr/bin/defaults", "write", "com.apple.controlcenter", "Clock", "-bool", "false"],
            ["/usr/bin/killall", "SystemUIServer"],
            ["/usr/bin/shortcuts", "run", "FocusOn"]
        ])
    }

    func test_turnOffCommands() {
        let commands = FocusAction.turnOff.commands
        XCTAssertEqual(commands, [
            ["/usr/bin/defaults", "write", "com.apple.controlcenter", "Clock", "-bool", "true"],
            ["/usr/bin/killall", "SystemUIServer"],
            ["/usr/bin/shortcuts", "run", "FocusOff"]
        ])
    }
}
