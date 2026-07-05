import XCTest
@testable import FindYourWayCore

/// `18_STAGE_B_SPEC.md` §2/§3/§6 + `19_STAGE_C_SPEC.md` §2/§5 + 美術大改版第 2 波
/// `21_ASSET_OVERHAUL_PLAN.md` §2（第 3 波以 harbor 取代 seaCity）：8 地域循環（grassland→
/// village2→valley→kingdom→village3→harbor→skyVillage→skyCity→回到 grassland）、
/// 邊界正確、Blend Zone crossfade 純函式（8 對相鄰邊界都要正確）。
final class RegionTests: XCTestCase {

    /// `21` §2 上線序列（第 3 波取代版），供以下測試逐一走過（比逐一手寫 8 個 case 更不容易
    /// 漏掉某對邊界）。
    private static let expectedCycle: [RegionType] = [
        .meadowOrigin, .village2, .valley, .kingdom, .village3, .harbor, .skyVillage, .skyCity,
    ]

    func testDistanceZeroIsFirstRegion() {
        XCTAssertEqual(Region.at(distance: 0), .meadowOrigin)
    }

    func testSameDistanceAlwaysProducesSameRegion() {
        for distance in [0.0, 12345.0, Region.regionLength, Region.regionLength * 3.5] {
            XCTAssertEqual(Region.at(distance: distance), Region.at(distance: distance))
        }
    }

    func testCyclesThroughAllEightRegionsInOrder() {
        let length = Region.regionLength
        let cycle = Self.expectedCycle
        XCTAssertEqual(cycle.count, 8, "8 地域循環（`21` §2），這裡先確認測試本身沒寫錯數量")

        // 走兩輪（16 個 band），確認每個 band 都落在預期地域、且能無縫接回第一輪。
        for round in 0..<2 {
            for (offset, expected) in cycle.enumerated() {
                let bandIndex = round * cycle.count + offset
                let distance = length * Double(bandIndex) + length / 2 // band 中段，避開邊界 blend zone
                XCTAssertEqual(
                    Region.at(distance: distance), expected,
                    "band \(bandIndex)（第 \(round) 輪第 \(offset) 個）應為 \(expected)"
                )
            }
        }
    }

    func testCyclesBackToFirstRegionAfterEightBands() {
        let length = Region.regionLength
        XCTAssertEqual(Region.at(distance: length * 8), .meadowOrigin)
        XCTAssertEqual(Region.at(distance: length * 16), .meadowOrigin)
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

    // MARK: - Blend Zone（`18` §3 / `19` §2 三對相鄰邊界）

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

    /// 8 地域循環的每一對相鄰邊界（含「回到第一個地域」那對）都要 crossfade 正確——
    /// 逐一手寫 8 份幾乎一樣的測試容易漏掉某一對，改成走過 `expectedCycle` 的資料驅動版本
    /// （比手寫 8 份更完整、也更不容易漏測）。
    func testBlendProgressesFromZeroToOneAcrossEveryAdjacentBoundary() {
        let length = Region.regionLength
        let halfWidth = Region.blendWidth / 2.0
        let cycle = Self.expectedCycle

        for bandIndex in 1...cycle.count {
            let from = cycle[(bandIndex - 1) % cycle.count]
            let to = cycle[bandIndex % cycle.count]
            let boundary = length * Double(bandIndex)

            let enter = Region.blend(atDistance: boundary - halfWidth)
            XCTAssertEqual(enter.from, from, "邊界 \(bandIndex) 進入點 from 錯誤")
            XCTAssertEqual(enter.to, to, "邊界 \(bandIndex) 進入點 to 錯誤")
            XCTAssertEqual(enter.t, 0, accuracy: 1e-9)

            let mid = Region.blend(atDistance: boundary)
            XCTAssertEqual(mid.from, from, "邊界 \(bandIndex) 中點 from 錯誤")
            XCTAssertEqual(mid.to, to, "邊界 \(bandIndex) 中點 to 錯誤")
            XCTAssertEqual(mid.t, 0.5, accuracy: 1e-9)

            let exit = Region.blend(atDistance: boundary + halfWidth)
            XCTAssertEqual(exit.from, from, "邊界 \(bandIndex) 離開點 from 錯誤")
            XCTAssertEqual(exit.to, to, "邊界 \(bandIndex) 離開點 to 錯誤")
            XCTAssertEqual(exit.t, 1, accuracy: 1e-9)
        }
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
