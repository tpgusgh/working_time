import XCTest
@testable import FocusToggle

final class ClockOverlayGeometryTests: XCTestCase {
    // Mirrors the live-verified setup: a 1512-wide primary screen (clock at
    // x=1371, w=135, "5pt from top", h=22) and a second 1920-wide screen
    // to its left at x=-1920.
    let primaryScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let clockFrame = CGRect(x: 1371, y: 5, width: 135, height: 22)

    func test_overlayOnPrimaryScreen_noPadding() {
        let frame = ClockOverlayGeometry.overlayFrame(
            forScreen: primaryScreenFrame,
            primaryScreenFrame: primaryScreenFrame,
            clockFrame: clockFrame,
            padding: 0
        )
        XCTAssertEqual(frame, CGRect(x: 1371, y: 955, width: 135, height: 22))
    }

    func test_overlayOnSecondaryScreen_toTheLeft_noPadding() {
        let secondaryScreenFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let frame = ClockOverlayGeometry.overlayFrame(
            forScreen: secondaryScreenFrame,
            primaryScreenFrame: primaryScreenFrame,
            clockFrame: clockFrame,
            padding: 0
        )
        XCTAssertEqual(frame, CGRect(x: -141, y: 1053, width: 135, height: 22))
    }

    func test_paddingGrowsFrameSymmetrically() {
        let frame = ClockOverlayGeometry.overlayFrame(
            forScreen: primaryScreenFrame,
            primaryScreenFrame: primaryScreenFrame,
            clockFrame: clockFrame,
            padding: 6
        )
        XCTAssertEqual(frame, CGRect(x: 1365, y: 949, width: 147, height: 34))
    }
}
