import XCTest
@testable import FocusToggle

final class ClockOverlayGeometryTests: XCTestCase {
    // Mirrors the live-verified setup: a 1512-wide primary screen (clock at
    // x=1371, w=135, "5pt from top", h=22) and a second 1920-wide screen
    // to its left at x=-1920.
    let primaryScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let secondaryScreenFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
    let clockFrame = CGRect(x: 1371, y: 5, width: 135, height: 22)

    func test_overlayOnPrimaryScreen_clockAlsoOnPrimary_noPadding() {
        let frame = ClockOverlayGeometry.overlayFrame(
            forScreen: primaryScreenFrame,
            sourceScreenFrame: primaryScreenFrame,
            clockFrame: clockFrame,
            padding: 0
        )
        XCTAssertEqual(frame, CGRect(x: 1371, y: 955, width: 135, height: 22))
    }

    func test_overlayOnSecondaryScreen_clockOnPrimary_noPadding() {
        let frame = ClockOverlayGeometry.overlayFrame(
            forScreen: secondaryScreenFrame,
            sourceScreenFrame: primaryScreenFrame,
            clockFrame: clockFrame,
            padding: 0
        )
        XCTAssertEqual(frame, CGRect(x: -141, y: 1053, width: 135, height: 22))
    }

    func test_paddingGrowsFrameSymmetrically() {
        let frame = ClockOverlayGeometry.overlayFrame(
            forScreen: primaryScreenFrame,
            sourceScreenFrame: primaryScreenFrame,
            clockFrame: clockFrame,
            padding: 6
        )
        XCTAssertEqual(frame, CGRect(x: 1365, y: 949, width: 147, height: 34))
    }

    // Regression test for the reported bug: toggling from the SECONDARY
    // display's menu bar makes AX report the clock's position on the
    // secondary screen instead of the primary one. The geometry math must
    // key off whichever screen the clock is actually on (sourceScreenFrame),
    // not always the primary screen, or the primary screen's own overlay
    // ends up wildly mispositioned.
    func test_clockReadFromSecondaryScreen_primaryOverlayStillCorrect() {
        // Clock frame as AX would report it while the secondary screen is
        // active: same size/top-offset and same 6pt distance from its own
        // screen's right edge as the primary-screen case above (clockFrame
        // x=1371, width=135, primaryScreenFrame maxX=1512 -> 6pt margin),
        // just measured within the secondary screen's coordinate space
        // (secondaryScreenFrame maxX=0 -> x=0-6-135=-141).
        let clockFrameOnSecondary = CGRect(x: -141, y: 5, width: 135, height: 22)

        let primaryOverlay = ClockOverlayGeometry.overlayFrame(
            forScreen: primaryScreenFrame,
            sourceScreenFrame: secondaryScreenFrame,
            clockFrame: clockFrameOnSecondary,
            padding: 0
        )
        XCTAssertEqual(primaryOverlay, CGRect(x: 1371, y: 955, width: 135, height: 22))

        let secondaryOverlay = ClockOverlayGeometry.overlayFrame(
            forScreen: secondaryScreenFrame,
            sourceScreenFrame: secondaryScreenFrame,
            clockFrame: clockFrameOnSecondary,
            padding: 0
        )
        XCTAssertEqual(secondaryOverlay, CGRect(x: -141, y: 1053, width: 135, height: 22))
    }
}
