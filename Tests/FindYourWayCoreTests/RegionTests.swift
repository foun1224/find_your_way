import XCTest
@testable import FindYourWayCore

/// `18_STAGE_B_SPEC.md` §2/§3/§6：meadow↔kingdom 交替、邊界正確、Blend Zone crossfade 純函式。
final class RegionTests: XCTestCase {

    func testDistanceZeroIsFirstRegion() {
        XCTAssertEqual(Region.at(distance: 0), .meadowOrigin)
    }

    func testSameDistanceAlwaysProducesSameRegion() {
        for distance in [0.0, 12345.0, Region.regionLength, Region.regionLength * 3.5] {
            XCTAssertEqual(Region.at(distance: distance), Region.at(distance: distance))
        }
    }

    func testAlternatesMeadowAndKingdom() {
        let length = Region.regionLength
        XCTAssertEqual(Region.at(distance: length - 1), .meadowOrigin)
        XCTAssertEqual(Region.at(distance: length), .kingdom)
        XCTAssertEqual(Region.at(distance: length * 2), .meadowOrigin)
        XCTAssertEqual(Region.at(distance: length * 3), .kingdom)
    }

    func testCyclesBackToFirstRegionAfterTwoBands() {
        let length = Region.regionLength
        XCTAssertEqual(Region.at(distance: length * 2), .meadowOrigin)
        XCTAssertEqual(Region.at(distance: length * 4), .meadowOrigin)
    }

    func testBandIndexMatchesFloorDivision() {
        let length = Region.regionLength
        XCTAssertEqual(Region.bandIndex(atDistance: 0), 0)
        XCTAssertEqual(Region.bandIndex(atDistance: length - 1), 0)
        XCTAssertEqual(Region.bandIndex(atDistance: length), 1)
    }

    func testStageBKeepsShortTravelInFirstRegion() {
        // regionLength 172800（≈4h）：短里程（幾小時內）仍在第一地域（meadow）。
        XCTAssertEqual(Region.at(distance: 43_200), .meadowOrigin)
    }

    // MARK: - Blend Zone（`18` §3）

    func testNoBlendAtJourneyStart() {
        // distance=0 恰為邊界倍數，但旅程起點前不存在地域，不應視為 Blend Zone。
        let blend = Region.blend(atDistance: 0)
        XCTAssertEqual(blend.from, blend.to)
        XCTAssertEqual(blend.t, 0)
    }

    func testNoBlendFarFromBoundary() {
        let length = Region.regionLength
        let blend = Region.blend(atDistance: length / 2)
        XCTAssertEqual(blend.from, blend.to)
        XCTAssertEqual(blend.t, 0)
    }

    func testBlendProgressesFromZeroToOneAcrossBoundary() {
        let length = Region.regionLength
        let halfWidth = Region.blendWidth / 2.0
        let boundary = length

        let enter = Region.blend(atDistance: boundary - halfWidth)
        XCTAssertEqual(enter.from, .meadowOrigin)
        XCTAssertEqual(enter.to, .kingdom)
        XCTAssertEqual(enter.t, 0, accuracy: 1e-9)

        let mid = Region.blend(atDistance: boundary)
        XCTAssertEqual(mid.from, .meadowOrigin)
        XCTAssertEqual(mid.to, .kingdom)
        XCTAssertEqual(mid.t, 0.5, accuracy: 1e-9)

        let exit = Region.blend(atDistance: boundary + halfWidth)
        XCTAssertEqual(exit.from, .meadowOrigin)
        XCTAssertEqual(exit.to, .kingdom)
        XCTAssertEqual(exit.t, 1, accuracy: 1e-9)
    }

    func testBlendIsMonotonicWithinZone() {
        let length = Region.regionLength
        let halfWidth = Region.blendWidth / 2.0
        let boundary = length

        var previousT = -1.0
        var distance = boundary - halfWidth
        while distance <= boundary + halfWidth {
            let blend = Region.blend(atDistance: distance)
            XCTAssertGreaterThanOrEqual(blend.t, previousT)
            previousT = blend.t
            distance += 500
        }
    }

    func testBlendZoneDoesNotExtendPastHalfWidth() {
        let length = Region.regionLength
        let halfWidth = Region.blendWidth / 2.0
        let boundary = length

        let justOutsideBefore = Region.blend(atDistance: boundary - halfWidth - 1)
        XCTAssertEqual(justOutsideBefore.from, justOutsideBefore.to)
        XCTAssertEqual(justOutsideBefore.t, 0)

        let justOutsideAfter = Region.blend(atDistance: boundary + halfWidth + 1)
        XCTAssertEqual(justOutsideAfter.from, justOutsideAfter.to)
        XCTAssertEqual(justOutsideAfter.t, 0)
    }

    func testBlendIsDeterministic() {
        let distance = Region.regionLength - 2000
        let a = Region.blend(atDistance: distance)
        let b = Region.blend(atDistance: distance)
        XCTAssertEqual(a, b)
    }
}
