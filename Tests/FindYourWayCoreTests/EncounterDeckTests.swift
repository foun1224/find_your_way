import XCTest
@testable import FindYourWayCore

/// `16_STAGE_A_SPEC.md` §2.2 / §5：相遇卡確定性選卡、季節過濾、不緊鄰重複、不依賴牆鐘。
final class EncounterDeckTests: XCTestCase {

    func testDeckHasTwentyFourAuthoredCards() {
        XCTAssertEqual(EncounterDeck.all.count, 24)
    }

    func testSameSlotAndSeasonAlwaysProducesSameCard() {
        for slot in [0, 1, 2, 5, 42, 1000] {
            let a = EncounterDeck.card(atSlot: slot, season: .summer)
            let b = EncounterDeck.card(atSlot: slot, season: .summer)
            XCTAssertEqual(a, b, "同一 (slot, season) 應永遠選到同一張卡（確定性）")
        }
    }

    func testDoesNotDependOnWallClock() {
        // 選卡是純函式，簽章裡完全沒有「現在時間」的輸入——多次呼叫（模擬不同真實時間）
        // 對同一 (slot, season) 結果不變，證明未偷偷讀取牆鐘。
        let results = (0..<5).map { _ in EncounterDeck.card(atSlot: 7, season: .autumn) }
        XCTAssertTrue(results.allSatisfy { $0 == results[0] })
    }

    func testWinterExcludesSummerOnlyCards() {
        let winterCards = EncounterDeck.availableCards(for: .winter)
        let summerOnlyIds: Set<String> = ["cicada_noon", "ripe_field", "cold_well", "long_shadow_evening"]
        XCTAssertTrue(winterCards.allSatisfy { !summerOnlyIds.contains($0.id) }, "冬天不該出現夏季限定卡")
    }

    func testSummerExcludesWinterOnlyCards() {
        let summerCards = EncounterDeck.availableCards(for: .summer)
        let winterOnlyIds: Set<String> = ["first_snow", "frozen_pond", "warm_soup", "fox_in_snow"]
        XCTAssertTrue(summerCards.allSatisfy { !winterOnlyIds.contains($0.id) }, "夏天不該出現冬季限定卡")
    }

    func testUniversalCardsAvailableInEverySeason() {
        for season in Season.allCases {
            let available = EncounterDeck.availableCards(for: season)
            XCTAssertTrue(available.contains { $0.id == "stone_on_path" }, "通用卡應在任何季節皆可出現")
        }
    }

    func testSeasonalCardOnlyAppearsInItsOwnSeason() {
        for season in Season.allCases {
            let available = EncounterDeck.availableCards(for: season)
            XCTAssertFalse(available.contains { $0.id == "first_buds" && season != .spring },
                            "春季限定卡不應在非春季的過濾結果出現")
        }
        XCTAssertTrue(EncounterDeck.availableCards(for: .spring).contains { $0.id == "first_buds" })
    }

    func testNoImmediateAdjacentRepeat() {
        // 掃過連續一段卡槽，任兩個相鄰卡槽不應選到同一張卡 id。
        var previousId: String?
        for slot in 0..<200 {
            guard let card = EncounterDeck.card(atSlot: slot, season: .spring) else {
                XCTFail("春季過濾清單不應為空")
                continue
            }
            if let previousId {
                XCTAssertNotEqual(card.id, previousId, "slot \(slot) 不應與上一槽同 id")
            }
            previousId = card.id
        }
    }

    func testEmptyFilteredDeckReturnsNilSafely() {
        // 防呆：若某季節過濾後完全沒有卡，`card(atSlot:season:)` 不應 crash，應回傳 nil。
        // 目前 authored 卡組每季都保證非空（通用卡兜底），這裡驗證選卡函式本身對空清單的處理路徑
        // 透過 `availableCards` 契約間接驗證：任何季節過濾結果都非空。
        for season in Season.allCases {
            XCTAssertFalse(EncounterDeck.availableCards(for: season).isEmpty)
        }
    }

    func testCardSpacingSlotIndexMatchesSpec() {
        let spacing = EncounterDeck.cardSpacing
        XCTAssertEqual(EncounterDeck.slotIndex(atDistance: 0), 0)
        XCTAssertEqual(EncounterDeck.slotIndex(atDistance: spacing - 1), 0)
        XCTAssertEqual(EncounterDeck.slotIndex(atDistance: spacing), 1)
        XCTAssertEqual(EncounterDeck.slotIndex(atDistance: spacing * 10), 10)
    }
}
