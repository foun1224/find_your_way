import XCTest
@testable import FindYourWayCore

final class WorldScrollTests: XCTestCase {

    func testScrollOffsetMovesNegativelyAsDistanceIncreases() {
        let offsetAt0 = WorldScroll.scrollOffset(forDistance: 0, layerFactor: 1.0)
        let offsetAt100 = WorldScroll.scrollOffset(forDistance: 100, layerFactor: 1.0)

        XCTAssertEqual(offsetAt0, 0)
        XCTAssertLessThan(offsetAt100, offsetAt0) // 世界向左捲：偏移越來越負
    }

    func testScrollOffsetIsMonotonicWithDistance() {
        var previous = WorldScroll.scrollOffset(forDistance: 0, layerFactor: 0.5)
        for distance in stride(from: 10.0, through: 100.0, by: 10.0) {
            let current = WorldScroll.scrollOffset(forDistance: distance, layerFactor: 0.5)
            XCTAssertLessThan(current, previous)
            previous = current
        }
    }

    func testDifferentLayerFactorsProduceDifferentScrollAmounts() {
        let distance = 200.0
        let farLayer = WorldScroll.scrollOffset(forDistance: distance, layerFactor: 0.1) // 遠景慢
        let nearLayer = WorldScroll.scrollOffset(forDistance: distance, layerFactor: 1.0) // 近景快

        XCTAssertGreaterThan(abs(nearLayer), abs(farLayer))
    }

    func testLandmarkScreenXAlignsWithCharacterWhenReached() {
        let anchorX = 100.0
        let x = WorldScroll.landmarkScreenX(landmarkDistance: 500, currentDistance: 500, characterAnchorX: anchorX)
        XCTAssertEqual(x, anchorX, accuracy: 0.0001)
    }

    func testLandmarkScreenXMovesLeftAsCurrentDistanceApproaches() {
        let anchorX = 100.0
        let landmarkDistance = 1_000.0

        let farX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 0, characterAnchorX: anchorX)
        let closerX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 500, characterAnchorX: anchorX)
        let atX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 1_000, characterAnchorX: anchorX)

        XCTAssertGreaterThan(farX, closerX)
        XCTAssertGreaterThan(closerX, atX)
        XCTAssertEqual(atX, anchorX, accuracy: 0.0001)
    }

    func testLandmarkScreenXContinuesMovingLeftAfterPassing() {
        let anchorX = 100.0
        let landmarkDistance = 1_000.0

        let atX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 1_000, characterAnchorX: anchorX)
        let passedX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 1_200, characterAnchorX: anchorX)

        XCTAssertLessThan(passedX, atX)
    }

    // MARK: - 可循環佔位景物 wrap（`08` §4b）

    func testWrappedXStaysWithinSpan() {
        let span = 400.0
        for distance in stride(from: 0.0, through: 2_000.0, by: 37.0) {
            let x = WorldScroll.wrappedX(baseX: 120, distance: distance, layerFactor: 1.0, span: span)
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThan(x, span)
        }
    }

    func testWrappedXMovesLeftAsDistanceIncreasesWithinOnePeriod() {
        let span = 400.0
        // 在一個週期內（未 wrap 前），distance 增加 → x 遞減（往左移）。
        let x0 = WorldScroll.wrappedX(baseX: 300, distance: 0, layerFactor: 1.0, span: span)
        let x1 = WorldScroll.wrappedX(baseX: 300, distance: 50, layerFactor: 1.0, span: span)
        let x2 = WorldScroll.wrappedX(baseX: 300, distance: 100, layerFactor: 1.0, span: span)
        XCTAssertLessThan(x1, x0)
        XCTAssertLessThan(x2, x1)
    }

    func testWrappedXIsPeriodicOverSpan() {
        let span = 400.0
        let baseX = 150.0
        // 位移剛好一個 span（distance*layerFactor == span）→ 回到起點。
        let x0 = WorldScroll.wrappedX(baseX: baseX, distance: 0, layerFactor: 1.0, span: span)
        let xSpan = WorldScroll.wrappedX(baseX: baseX, distance: span, layerFactor: 1.0, span: span)
        XCTAssertEqual(x0, xSpan, accuracy: 0.0001)
    }

    func testWrappedXWrapsBackToRightAfterCrossingZero() {
        let span = 400.0
        // baseX 很小，稍微位移就越過 0 → wrap 到接近 span（右側重新進場）。
        let x = WorldScroll.wrappedX(baseX: 10, distance: 50, layerFactor: 1.0, span: span)
        XCTAssertEqual(x, 360, accuracy: 0.0001) // 10 - 50 = -40 → +400 = 360
    }

    func testWrappedXDifferentLayerFactorsScrollAtDifferentRates() {
        let span = 400.0
        let distance = 100.0
        let far = WorldScroll.wrappedX(baseX: 300, distance: distance, layerFactor: 0.3, span: span)
        let near = WorldScroll.wrappedX(baseX: 300, distance: distance, layerFactor: 1.0, span: span)
        // 近景移動較多（離基準槽位更遠）。
        XCTAssertGreaterThan(300 - near, 300 - far)
    }

    func testWrappedXZeroSpanReturnsBaseX() {
        let x = WorldScroll.wrappedX(baseX: 42, distance: 999, layerFactor: 1.0, span: 0)
        XCTAssertEqual(x, 42, accuracy: 0.0001)
    }

    func testCharacterScreenXWithinExpectedLeftBand() {
        let sceneWidth = 320.0
        let x = WorldScroll.characterScreenX(sceneWidth: sceneWidth)

        // ADR-009：畫面左側約 20–25%
        XCTAssertGreaterThanOrEqual(x, sceneWidth * 0.15)
        XCTAssertLessThanOrEqual(x, sceneWidth * 0.30)
    }
}
