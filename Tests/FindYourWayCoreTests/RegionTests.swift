import XCTest
@testable import FindYourWayCore

/// `16_STAGE_A_SPEC.md` §2.3b / §5：Region 薄骨架，確定性、邊界正確。
final class RegionTests: XCTestCase {

    func testDistanceZeroIsFirstRegion() {
        XCTAssertEqual(Region.at(distance: 0), .meadowOrigin)
    }

    func testSameDistanceAlwaysProducesSameRegion() {
        for distance in [0.0, 12345.0, Region.regionLength, Region.regionLength * 3.5] {
            XCTAssertEqual(Region.at(distance: distance), Region.at(distance: distance))
        }
    }

    func testBandBoundaries() {
        let length = Region.regionLength
        XCTAssertEqual(Region.at(distance: length - 1), .meadowOrigin)
        XCTAssertEqual(Region.at(distance: length), .riverlands)
        XCTAssertEqual(Region.at(distance: length * 2), .highlands)
        XCTAssertEqual(Region.at(distance: length * 3), .coastalReach)
    }

    func testCyclesBackToFirstRegionAfterFourBands() {
        let length = Region.regionLength
        XCTAssertEqual(Region.at(distance: length * 4), .meadowOrigin)
    }

    func testBandIndexMatchesFloorDivision() {
        let length = Region.regionLength
        XCTAssertEqual(Region.bandIndex(atDistance: 0), 0)
        XCTAssertEqual(Region.bandIndex(atDistance: length - 1), 0)
        XCTAssertEqual(Region.bandIndex(atDistance: length), 1)
    }

    func testStageAKeepsMostTravelInFirstRegion() {
        // Stage A provisional：regionLength 夠大，短里程（幾小時內）仍在第一地域。
        XCTAssertEqual(Region.at(distance: 43_200), .meadowOrigin)
    }
}
