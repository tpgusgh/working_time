import XCTest
@testable import FocusToggle

final class ToggleStateTests: XCTestCase {
    func test_startsOff() {
        let state = ToggleState()
        XCTAssertFalse(state.isOn)
    }

    func test_toggleFlipsOnThenOff() {
        let state = ToggleState()
        XCTAssertTrue(state.toggle())
        XCTAssertTrue(state.isOn)
        XCTAssertFalse(state.toggle())
        XCTAssertFalse(state.isOn)
    }
}
