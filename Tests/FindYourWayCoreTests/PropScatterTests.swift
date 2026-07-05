import XCTest
@testable import FindYourWayCore

/// `PropScatter` 是純資料 + 純函式（Phase 4b `12` §2/§6）：確定性槽位表，
/// 同一 `distance` 永遠得到同一畫面（非隨機），下面驗證這個「確定性」與基本幾何不變量。
final class PropScatterTests: XCTestCase {

    func testSlotsAreWithinSpan() {
        for slot in PropScatter.slots {
            XCTAssertGreaterThanOrEqual(slot.baseX, 0)
            XCTAssertLessThan(slot.baseX, PropScatter.span)
        }
    }

    func testSlotsAreSortedAndNonOverlapping() {
        let baseXs = PropScatter.slots.map(\.baseX)
        XCTAssertEqual(baseXs, baseXs.sorted(), "槽位表應依 baseX 遞增排列，方便閱讀與維護")

        for i in 1..<baseXs.count {
            XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "相鄰槽位不可重疊")
        }
    }

    func testScreenXIsDeterministicForSameDistance() {
        guard let slot = PropScatter.slots.first else {
            return XCTFail("預期至少有一個槽位")
        }
        let x1 = PropScatter.screenX(for: slot, distance: 12_345)
        let x2 = PropScatter.screenX(for: slot, distance: 12_345)
        XCTAssertEqual(x1, x2, "同一 distance 必須得到同一畫面（純裝飾、確定性、不入 GameState）")
    }

    func testScreenXStaysWithinSpanAcrossDistances() {
        for slot in PropScatter.slots {
            for distance in stride(from: 0.0, through: 5_000.0, by: 137.0) {
                let x = PropScatter.screenX(for: slot, distance: distance)
                XCTAssertGreaterThanOrEqual(x, 0)
                XCTAssertLessThan(x, PropScatter.span)
            }
        }
    }

    func testScreenXMovesLeftAsDistanceIncreasesWithinOnePeriod() {
        // 挑選 baseX 夠大的槽位，避免小位移就 wrap 一圈回到右側（`WorldScrollTests` 已涵蓋 wrap 語意本身）。
        guard let slot = PropScatter.slots.last else {
            return XCTFail("預期至少有一個槽位")
        }
        let x0 = PropScatter.screenX(for: slot, distance: 0)
        let x1 = PropScatter.screenX(for: slot, distance: 50)
        XCTAssertLessThan(x1, x0)
    }

    func testAllSlotPropNamesAreNonEmpty() {
        for slot in PropScatter.slots {
            XCTAssertFalse(slot.propName.isEmpty)
        }
    }

    // MARK: - 地域化道具池（`18_STAGE_B_SPEC.md` §1/§3）

    func testKingdomSlotsAreWithinSpanAndSortedAndNonEmpty() {
        let baseXs = PropScatter.kingdomSlots.map(\.baseX)
        XCTAssertEqual(baseXs, baseXs.sorted(), "王國槽位表應依 baseX 遞增排列")
        for i in 1..<baseXs.count {
            XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "相鄰槽位不可重疊")
        }
        for slot in PropScatter.kingdomSlots {
            XCTAssertGreaterThanOrEqual(slot.baseX, 0)
            XCTAssertLessThan(slot.baseX, PropScatter.span)
            XCTAssertFalse(slot.propName.isEmpty)
        }
    }

    func testSlotsForRegionPicksMeadowOrKingdomPool() {
        XCTAssertEqual(PropScatter.slots(for: .meadowOrigin), PropScatter.slots)
        XCTAssertEqual(PropScatter.slots(for: .kingdom), PropScatter.kingdomSlots)
    }

    // MARK: - 港口海城道具池（`19_STAGE_C_SPEC.md` §1/§3，第三地域）

    func testSeaCitySlotsAreWithinSpanAndSortedAndNonEmpty() {
        let baseXs = PropScatter.seaCitySlots.map(\.baseX)
        XCTAssertEqual(baseXs, baseXs.sorted(), "海城槽位表應依 baseX 遞增排列")
        for i in 1..<baseXs.count {
            XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "相鄰槽位不可重疊")
        }
        for slot in PropScatter.seaCitySlots {
            XCTAssertGreaterThanOrEqual(slot.baseX, 0)
            XCTAssertLessThan(slot.baseX, PropScatter.span)
            XCTAssertFalse(slot.propName.isEmpty)
        }
    }

    func testSlotsForRegionPicksSeaCityPool() {
        XCTAssertEqual(PropScatter.slots(for: .seaCity), PropScatter.seaCitySlots)
    }

    // MARK: - 港口地域道具池（`20_ASSET_SHEET_SPEC.md` §8A 驗證通過，`21` §2 第 3 波取代 seaCity 排進 8 地域循環）

    func testHarborSlotsAreWithinSpanAndSortedAndNonEmpty() {
        let baseXs = PropScatter.harborSlots.map(\.baseX)
        XCTAssertEqual(baseXs, baseXs.sorted(), "海港槽位表應依 baseX 遞增排列")
        XCTAssertFalse(PropScatter.harborSlots.isEmpty, "海港槽位表不應為空")
        for i in 1..<baseXs.count {
            XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "相鄰槽位不可重疊")
        }
        for slot in PropScatter.harborSlots {
            XCTAssertGreaterThanOrEqual(slot.baseX, 0)
            XCTAssertLessThan(slot.baseX, PropScatter.span)
            XCTAssertFalse(slot.propName.isEmpty)
        }
    }

    func testSlotsForRegionPicksHarborPool() {
        XCTAssertEqual(PropScatter.slots(for: .harbor), PropScatter.harborSlots)
        XCTAssertFalse(PropScatter.slots(for: .harbor).isEmpty, "海港已排進 8 地域循環，不該再是空槽位表")
    }

    // MARK: - 美術大改版第 2 波新地域道具池（`21_ASSET_OVERHAUL_PLAN.md` §4，8 地域循環）

    /// 逐一驗證 5 個新地域槽位表的基本不變量（同 `testKingdomSlotsAreWithinSpanAndSortedAndNonEmpty`/
    /// `testSeaCitySlotsAreWithinSpanAndSortedAndNonEmpty` 手法），資料驅動避免 5 份幾乎重複的測試。
    func testNewRegionSlotsAreWithinSpanAndSortedAndNonEmpty() {
        let tables: [(String, [PropScatter.Slot])] = [
            ("valley", PropScatter.valleySlots),
            ("village2", PropScatter.village2Slots),
            ("village3", PropScatter.village3Slots),
            ("skyVillage", PropScatter.skyVillageSlots),
            ("skyCity", PropScatter.skyCitySlots),
        ]
        for (name, slots) in tables {
            let baseXs = slots.map(\.baseX)
            XCTAssertEqual(baseXs, baseXs.sorted(), "\(name) 槽位表應依 baseX 遞增排列")
            XCTAssertFalse(slots.isEmpty, "\(name) 槽位表不應為空")
            for i in 1..<baseXs.count {
                XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "\(name) 相鄰槽位不可重疊")
            }
            for slot in slots {
                XCTAssertGreaterThanOrEqual(slot.baseX, 0, "\(name) baseX 不可為負")
                XCTAssertLessThan(slot.baseX, PropScatter.span, "\(name) baseX 需落在 span 內")
                XCTAssertFalse(slot.propName.isEmpty, "\(name) propName 不可為空")
            }
        }
    }

    func testSlotsForRegionPicksEachOfTheFiveNewRegionPools() {
        XCTAssertEqual(PropScatter.slots(for: .valley), PropScatter.valleySlots)
        XCTAssertEqual(PropScatter.slots(for: .village2), PropScatter.village2Slots)
        XCTAssertEqual(PropScatter.slots(for: .village3), PropScatter.village3Slots)
        XCTAssertEqual(PropScatter.slots(for: .skyVillage), PropScatter.skyVillageSlots)
        XCTAssertEqual(PropScatter.slots(for: .skyCity), PropScatter.skyCitySlots)
    }
}
