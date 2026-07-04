import XCTest
@testable import FindYourWayCore

final class WindowPlacementTests: XCTestCase {

    func testClampedOriginUnchangedWhenAlreadyInside() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        let origin = CGPoint(x: 500, y: 300)

        let clamped = WindowPlacement.clampedOrigin(origin, windowSize: windowSize, visibleFrame: visibleFrame)

        XCTAssertEqual(clamped, origin)
    }

    func testClampedOriginPulledBackWhenPastRightEdge() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        let origin = CGPoint(x: 2000, y: 300)

        let clamped = WindowPlacement.clampedOrigin(origin, windowSize: windowSize, visibleFrame: visibleFrame)

        XCTAssertEqual(clamped.x, visibleFrame.maxX - windowSize.width, accuracy: 0.0001)
        XCTAssertEqual(clamped.y, 300, accuracy: 0.0001)
    }

    func testClampedOriginPulledBackWhenBelowLeftBottomEdge() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        let origin = CGPoint(x: -500, y: -500)

        let clamped = WindowPlacement.clampedOrigin(origin, windowSize: windowSize, visibleFrame: visibleFrame)

        XCTAssertEqual(clamped.x, visibleFrame.minX, accuracy: 0.0001)
        XCTAssertEqual(clamped.y, visibleFrame.minY, accuracy: 0.0001)
    }

    func testClampedOriginResultAlwaysContainedInVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = PetWindowConfig.defaultSize

        for origin in [
            CGPoint(x: -1000, y: -1000),
            CGPoint(x: 5000, y: 5000),
            CGPoint(x: 800, y: 400)
        ] {
            let clamped = WindowPlacement.clampedOrigin(origin, windowSize: windowSize, visibleFrame: visibleFrame)
            let frame = CGRect(origin: clamped, size: windowSize)
            XCTAssertTrue(visibleFrame.contains(frame), "frame \(frame) should be contained in \(visibleFrame)")
        }
    }

    func testIsOriginWithinAnyScreenTrueWhenIntersectingOneOfMany() {
        let screenA = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screenB = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let windowSize = CGSize(width: 320, height: 180)
        let origin = CGPoint(x: 1500, y: 100)

        XCTAssertTrue(WindowPlacement.isOriginWithinAnyScreen(origin, windowSize: windowSize, visibleFrames: [screenA, screenB]))
    }

    func testIsOriginWithinAnyScreenFalseWhenOffAllScreens() {
        let screenA = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        // 外接螢幕曾在 x: 1440..3360 的範圍，拔除後只剩 screenA。
        let origin = CGPoint(x: 3000, y: 100)

        XCTAssertFalse(WindowPlacement.isOriginWithinAnyScreen(origin, windowSize: windowSize, visibleFrames: [screenA]))
    }

    func testOwningVisibleFramePicksTheIntersectingScreen() {
        let screenA = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screenB = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let windowSize = CGSize(width: 320, height: 180)
        let origin = CGPoint(x: 1500, y: 100)

        let owning = WindowPlacement.owningVisibleFrame(for: origin, windowSize: windowSize, visibleFrames: [screenA, screenB])

        XCTAssertEqual(owning, screenB)
    }

    func testOwningVisibleFrameNilWhenNoScreenMatches() {
        let screenA = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        let origin = CGPoint(x: 3000, y: 100)

        XCTAssertNil(WindowPlacement.owningVisibleFrame(for: origin, windowSize: windowSize, visibleFrames: [screenA]))
    }
}
