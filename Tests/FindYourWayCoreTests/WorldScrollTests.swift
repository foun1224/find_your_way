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

    func testCharacterScreenXWithinExpectedLeftBand() {
        let sceneWidth = 320.0
        let x = WorldScroll.characterScreenX(sceneWidth: sceneWidth)

        // ADR-009：畫面左側約 20–25%
        XCTAssertGreaterThanOrEqual(x, sceneWidth * 0.15)
        XCTAssertLessThanOrEqual(x, sceneWidth * 0.30)
    }
}
