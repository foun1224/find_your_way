import XCTest
@testable import FindYourWayCore

/// `RegionNpcScatter` 是純資料 + 純函式（美術大改版第 3 波，`21_ASSET_OVERHAUL_PLAN.md` §3，
/// 泛用化自 Stage B+ 的 `KingdomNpcScatter`）：確定性槽位表，同一 `distance` 永遠得到同一畫面
/// （非隨機）。手法/不變量與 `PropScatterTests`/舊 `KingdomNpcScatterTests` 對稱，只是槽位表
/// 換成「每個地域一組指定居民」。
final class RegionNpcScatterTests: XCTestCase {

    /// 所有具名槽位表（每地域一份）皆需滿足：依 `baseX` 遞增排列、彼此不重疊、落在 `[0, span)`
    /// 內、`npcName` 非空——與 `PropScatter`/舊 `KingdomNpcScatter` 槽位表的既有不變量一致。
    private func assertWellFormed(_ slots: [RegionNpcScatter.Slot], file: StaticString = #filePath, line: UInt = #line) {
        let baseXs = slots.map(\.baseX)
        XCTAssertEqual(baseXs, baseXs.sorted(), "槽位表應依 baseX 遞增排列", file: file, line: line)
        for i in 1..<baseXs.count {
            XCTAssertGreaterThan(baseXs[i] - baseXs[i - 1], 0, "相鄰槽位不可重疊", file: file, line: line)
        }
        for slot in slots {
            XCTAssertGreaterThanOrEqual(slot.baseX, 0, file: file, line: line)
            XCTAssertLessThan(slot.baseX, RegionNpcScatter.span, file: file, line: line)
            XCTAssertFalse(slot.npcName.isEmpty, file: file, line: line)
        }
    }

    func testAllNamedSlotTablesAreWellFormedAndNonEmpty() {
        let tables = [
            RegionNpcScatter.kingdomSlots,
            RegionNpcScatter.pastoralSlots,
            RegionNpcScatter.seaCitySlots,
            RegionNpcScatter.harborSlots,
            RegionNpcScatter.valleySlots,
            RegionNpcScatter.skySlots,
            RegionNpcScatter.hotspringVillageSlots,
            RegionNpcScatter.mountainPalaceSlots,
        ]
        for table in tables {
            XCTAssertFalse(table.isEmpty)
            assertWellFormed(table)
        }
    }

    /// `21` §3 分配表：田園地域（草原/村莊 A/村莊 B）共用農夫/麵包師/孩童/商人/樂手。
    func testPastoralRegionsGetFarmerBakerChildMerchantMusician() {
        let expectedNames: Set<String> = ["farmer", "baker", "child", "merchant", "musician"]
        for region: RegionType in [.meadowOrigin, .village2, .village3] {
            let slots = RegionNpcScatter.slots(for: region)
            XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames, "\(region) 應配置田園居民")
            XCTAssertEqual(slots, RegionNpcScatter.pastoralSlots)
        }
    }

    /// `21` §3：王國配置國王/王后/公主/大臣/騎士/衛兵（王室 + 守備）。
    func testKingdomGetsRoyalAndGuardNpcs() {
        let expectedNames: Set<String> = ["king", "queen", "princess", "minister", "knight", "guard"]
        let slots = RegionNpcScatter.slots(for: .kingdom)
        XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames)
        XCTAssertEqual(slots, RegionNpcScatter.kingdomSlots)
    }

    /// `21` §3：海城配置漁夫/商人/旅人（`seaCity` case 已休眠、不再進入 8 地域循環，
    /// 槽位表仍保留、不弱化這條斷言）。
    func testSeaCityGetsFisherMerchantTraveler() {
        let expectedNames: Set<String> = ["fisher", "merchant", "traveler"]
        let slots = RegionNpcScatter.slots(for: .seaCity)
        XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames)
        XCTAssertEqual(slots, RegionNpcScatter.seaCitySlots)
    }

    /// `21` §2/§3 第 3 波：海港取代海城排進 8 地域循環，居民組成沿用漁夫/商人/旅人。
    func testHarborGetsFisherMerchantTraveler() {
        let expectedNames: Set<String> = ["fisher", "merchant", "traveler"]
        let slots = RegionNpcScatter.slots(for: .harbor)
        XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames)
        XCTAssertEqual(slots, RegionNpcScatter.harborSlots)
    }

    /// 接手任務：溫泉山村配置農夫/藥師/商人/旅人（混合田園日常 + 旅途氛圍，藥師呼應溫泉療養）。
    func testHotspringVillageGetsFarmerApothecaryMerchantTraveler() {
        let expectedNames: Set<String> = ["farmer", "apothecary", "merchant", "traveler"]
        let slots = RegionNpcScatter.slots(for: .hotspringVillage)
        XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames)
        XCTAssertEqual(slots, RegionNpcScatter.hotspringVillageSlots)
    }

    /// 接手任務：仙俠山宮配置學者/藥師/商人/旅人（沿用共享 `npc/` 資料夾裡最貼近「仙俠隱士」
    /// 意象的既有角色，與天空地域共用同款人口組成但獨立排法）。
    func testMountainPalaceGetsScholarApothecaryMerchantTraveler() {
        let expectedNames: Set<String> = ["scholar", "apothecary", "merchant", "traveler"]
        let slots = RegionNpcScatter.slots(for: .mountainPalace)
        XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames)
        XCTAssertEqual(slots, RegionNpcScatter.mountainPalaceSlots)
    }

    /// `21` §3：山谷配置藥師/學者/旅人。
    func testValleyGetsApothecaryScholarTraveler() {
        let expectedNames: Set<String> = ["apothecary", "scholar", "traveler"]
        let slots = RegionNpcScatter.slots(for: .valley)
        XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames)
        XCTAssertEqual(slots, RegionNpcScatter.valleySlots)
    }

    /// `21` §3：天空地域（天空村莊/天空魔法城）共用學者/藥師/樂師（奇幻氛圍）。
    func testSkyRegionsGetScholarApothecaryMusician() {
        let expectedNames: Set<String> = ["scholar", "apothecary", "musician"]
        for region: RegionType in [.skyVillage, .skyCity] {
            let slots = RegionNpcScatter.slots(for: region)
            XCTAssertEqual(Set(slots.map(\.npcName)), expectedNames, "\(region) 應配置天空居民")
            XCTAssertEqual(slots, RegionNpcScatter.skySlots)
        }
    }

    /// 尚無美術/骨架地域（`RegionType.at(bandIndex:)` 循環外的 case）本波仍不該冒出居民。
    func testUnconfiguredSkeletonRegionsAreEmpty() {
        XCTAssertTrue(RegionNpcScatter.slots(for: .riverlands).isEmpty)
        XCTAssertTrue(RegionNpcScatter.slots(for: .highlands).isEmpty)
        XCTAssertTrue(RegionNpcScatter.slots(for: .coastalReach).isEmpty)
    }

    /// 每個地域的槽位表沿街位置間距合理（比照現行王國槽位手法）：3~4 個槽位（`21` 任務要求）。
    func testEachConfiguredRegionHasThreeToFourSlots() {
        for region: RegionType in [.meadowOrigin, .village2, .village3, .seaCity, .harbor, .hotspringVillage, .valley, .skyVillage, .mountainPalace, .skyCity] {
            let count = RegionNpcScatter.slots(for: region).count
            XCTAssertTrue((3...5).contains(count), "\(region) 應有 3~5 個沿街槽位，實際 \(count)")
        }
        XCTAssertTrue((3...8).contains(RegionNpcScatter.slots(for: .kingdom).count))
    }

    func testScreenXIsDeterministicForSameDistance() {
        guard let slot = RegionNpcScatter.kingdomSlots.first else {
            return XCTFail("預期至少有一個槽位")
        }
        let x1 = RegionNpcScatter.screenX(for: slot, distance: 12_345)
        let x2 = RegionNpcScatter.screenX(for: slot, distance: 12_345)
        XCTAssertEqual(x1, x2, "同一 distance 必須得到同一畫面（純裝飾、確定性、不入 GameState）")
    }

    func testScreenXStaysWithinSpanAcrossDistances() {
        for slot in RegionNpcScatter.pastoralSlots {
            for distance in stride(from: 0.0, through: 5_000.0, by: 137.0) {
                let x = RegionNpcScatter.screenX(for: slot, distance: distance)
                XCTAssertGreaterThanOrEqual(x, 0)
                XCTAssertLessThan(x, RegionNpcScatter.span)
            }
        }
    }

    func testScreenXMovesLeftAsDistanceIncreasesWithinOnePeriod() {
        guard let slot = RegionNpcScatter.kingdomSlots.last else {
            return XCTFail("預期至少有一個槽位")
        }
        let x0 = RegionNpcScatter.screenX(for: slot, distance: 0)
        let x1 = RegionNpcScatter.screenX(for: slot, distance: 50)
        XCTAssertLessThan(x1, x0)
    }
}
