import XCTest
@testable import FindYourWayCore

/// `KingdomNpcScatter` 是純資料 + 純函式（Stage B+，`02_PSYCHOLOGY_FOUNDATION.md` §2 社會臨場感）：
/// 確定性槽位表，同一 `distance` 永遠得到同一畫面（非隨機）。手法/不變量與 `PropScatterTests`
/// 對稱，只是槽位表放的是市民 NPC 而非道具。
final class KingdomNpcScatterTests: XCTestCase {

    func testKingdomSlotsAreWithinSpanAndSortedAndNonEmpty() {
        let baseXs = KingdomNpcScatter.kingdomSlots.map(\.baseX)
        XCTAssertEqual(baseXs, baseXs.sorted(), "槽位表應依 baseX 遞增排列")
        for i in 1..<baseXs.count {
            XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "相鄰槽位不可重疊")
        }
        for slot in KingdomNpcScatter.kingdomSlots {
            XCTAssertGreaterThanOrEqual(slot.baseX, 0)
            XCTAssertLessThan(slot.baseX, KingdomNpcScatter.span)
            XCTAssertFalse(slot.npcName.isEmpty)
        }
    }

    func testSlotsForRegionOnlyPopulatesKingdom() {
        XCTAssertEqual(KingdomNpcScatter.slots(for: .kingdom), KingdomNpcScatter.kingdomSlots)
        XCTAssertTrue(KingdomNpcScatter.slots(for: .meadowOrigin).isEmpty, "草原是荒野，不該冒出市民")
        XCTAssertTrue(KingdomNpcScatter.slots(for: .riverlands).isEmpty)
        XCTAssertTrue(KingdomNpcScatter.slots(for: .highlands).isEmpty)
        XCTAssertTrue(KingdomNpcScatter.slots(for: .coastalReach).isEmpty)
    }

    func testScreenXIsDeterministicForSameDistance() {
        guard let slot = KingdomNpcScatter.kingdomSlots.first else {
            return XCTFail("預期至少有一個槽位")
        }
        let x1 = KingdomNpcScatter.screenX(for: slot, distance: 12_345)
        let x2 = KingdomNpcScatter.screenX(for: slot, distance: 12_345)
        XCTAssertEqual(x1, x2, "同一 distance 必須得到同一畫面（純裝飾、確定性、不入 GameState）")
    }

    func testScreenXStaysWithinSpanAcrossDistances() {
        for slot in KingdomNpcScatter.kingdomSlots {
            for distance in stride(from: 0.0, through: 5_000.0, by: 137.0) {
                let x = KingdomNpcScatter.screenX(for: slot, distance: distance)
                XCTAssertGreaterThanOrEqual(x, 0)
                XCTAssertLessThan(x, KingdomNpcScatter.span)
            }
        }
    }

    func testScreenXMovesLeftAsDistanceIncreasesWithinOnePeriod() {
        guard let slot = KingdomNpcScatter.kingdomSlots.last else {
            return XCTFail("預期至少有一個槽位")
        }
        let x0 = KingdomNpcScatter.screenX(for: slot, distance: 0)
        let x1 = KingdomNpcScatter.screenX(for: slot, distance: 50)
        XCTAssertLessThan(x1, x0)
    }
}
