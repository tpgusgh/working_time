import XCTest
@testable import FocusToggle

final class FocusActionTests: XCTestCase {
    func test_turnOnCommands() {
        let commands = FocusAction.turnOn.commands
        XCTAssertEqual(commands, [
            ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "0"],
            ["/usr/bin/killall", "ControlCenter"],
            ["/usr/bin/shortcuts", "run", "FocusOn"]
        ])
    }

    func test_turnOffCommands() {
        let commands = FocusAction.turnOff.commands
        XCTAssertEqual(commands, [
            ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "1"],
            ["/usr/bin/killall", "ControlCenter"],
            ["/usr/bin/shortcuts", "run", "FocusOff"]
        ])
    }
}
