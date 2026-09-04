import XCTest
@testable import FocusToggle

final class MenuBarIconStyleTests: XCTestCase {
    func test_everyStyleHasDistinctOnAndOffSymbols() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertNotEqual(style.offSymbol, style.onSymbol, "\(style) must use different symbols for on/off")
            XCTAssertFalse(style.displayName.isEmpty)
        }
    }

    func test_rawValueRoundTrips() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertEqual(MenuBarIconStyle(rawValue: style.rawValue), style)
        }
    }
}
