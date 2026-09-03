import XCTest
@testable import FocusToggle

final class FocusActionTests: XCTestCase {
    func test_turnOnCommands() {
        XCTAssertEqual(FocusAction.turnOn.commands, [
            ["/usr/bin/shortcuts", "run", "FocusOn"]
        ])
    }

    func test_turnOffCommands() {
        XCTAssertEqual(FocusAction.turnOff.commands, [
            ["/usr/bin/shortcuts", "run", "FocusOff"]
        ])
    }
}
