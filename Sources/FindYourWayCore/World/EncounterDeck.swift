import Foundation

/// 相遇卡組與確定性選卡（`16_STAGE_A_SPEC.md` §2.2/§3）。純函式、**不依賴牆鐘**：
/// 同一個 `(worldSeed, slotIndex, season)` 永遠選到同一張卡，離線可重算。
public enum EncounterDeck {

    /// 沿里程軸每 `cardSpacing` 一個「卡槽」（provisional，≈40min travel，`16` §2.2）。
    public static let cardSpacing: Double = 28_800

    /// 固定編譯常數：**不依賴牆鐘**，只是讓選卡結果的分布看起來不那麼規律。
    private static let worldSeed: UInt64 = 0x46_59_57_5F_53_65_65_64 // "FYW_Seed" ascii bytes

    /// `slotIndex = floor(distance / cardSpacing)`。
    public static func slotIndex(atDistance distance: Double) -> Int {
        Int(floor(distance / cardSpacing))
    }

    // MARK: - Authored 卡組（`16` §3，24 張起手；文案一字不改）

    /// 通用（任何季節）。
    private static let universal: [EncounterCard] = [
        EncounterCard(id: "stone_on_path", category: .scenery, logText: "路上有塊被很多人踩過、踩得發亮的石頭。"),
        EncounterCard(id: "distant_bell", category: .culture, logText: "遠處傳來一下鐘聲，很輕，像誰在報時，又像沒有。"),
        EncounterCard(id: "resting_traveler", category: .culture, logText: "一個人靠在樹下打盹，你放輕了腳步。"),
        EncounterCard(id: "wind_direction", category: .scenery, logText: "風換了個方向。你也跟著側了側身。"),
        EncounterCard(id: "companion_hums", category: .companion, logText: "他哼了一小段調子，你沒聽過，但很好聽。"),
        EncounterCard(id: "share_water", category: .companion, logText: "你們分了同一壺水。剩下的路好像短了一點。"),
        EncounterCard(id: "old_milestone", category: .scenery, logText: "路邊一塊舊里程碑，字被磨平了，方向還在。"),
        EncounterCard(id: "kind_dog", category: .fauna, logText: "一隻狗跟了你們一小段，到牠家門口就停下了。")
    ]

    /// 春 Spring。
    private static let spring: [EncounterCard] = [
        EncounterCard(id: "first_buds", category: .flora, seasons: [.spring], logText: "枝頭冒出第一點綠，小心翼翼的樣子。"),
        EncounterCard(id: "spring_stream", category: .scenery, seasons: [.spring], logText: "雪水下山，溪聲比昨天響。"),
        EncounterCard(id: "nesting_birds", category: .fauna, seasons: [.spring], logText: "兩隻鳥在銜草築巢，忙得沒空理你。"),
        EncounterCard(id: "warm_bread", category: .food, seasons: [.spring], logText: "路過的村子在烤麵包，香味把你留了半刻。")
    ]

    /// 夏 Summer。
    private static let summer: [EncounterCard] = [
        EncounterCard(id: "cicada_noon", category: .fauna, seasons: [.summer], logText: "午後的蟬聲很滿，滿到讓人想找棵樹坐下。"),
        EncounterCard(id: "ripe_field", category: .flora, seasons: [.summer], logText: "一整片麥子熟了，風一過就是一片金色的浪。"),
        EncounterCard(id: "cold_well", category: .food, seasons: [.summer], logText: "井水冰涼，有人遞了你一瓢。"),
        EncounterCard(id: "long_shadow_evening", category: .scenery, seasons: [.summer], logText: "夏天的黃昏很長，影子拉得老遠。")
    ]

    /// 秋 Autumn。
    private static let autumn: [EncounterCard] = [
        EncounterCard(id: "falling_leaves", category: .flora, seasons: [.autumn], logText: "葉子開始落了，踩上去有聲音。"),
        EncounterCard(id: "harvest_cart", category: .culture, seasons: [.autumn], logText: "一車剛收的果子經過，紅得發亮。"),
        EncounterCard(id: "roasted_chestnut", category: .food, seasons: [.autumn], logText: "街角在炒栗子，你買了一小袋，暖手。"),
        EncounterCard(id: "migrating_geese", category: .fauna, seasons: [.autumn], logText: "一行雁往南去，你抬頭看了很久。")
    ]

    /// 冬 Winter：安靜乾淨的白，不做蕭瑟/死亡壓力（`16` §1.2）。
    private static let winter: [EncounterCard] = [
        EncounterCard(id: "first_snow", category: .scenery, seasons: [.winter], logText: "今年的第一場雪，很輕，落在肩上就化了。"),
        EncounterCard(id: "frozen_pond", category: .scenery, seasons: [.winter], logText: "池面結了薄冰，映著乾淨的天。"),
        EncounterCard(id: "warm_soup", category: .food, seasons: [.winter], logText: "有人請你喝了碗熱湯，說了句你聽不懂但很暖的話。"),
        EncounterCard(id: "fox_in_snow", category: .fauna, seasons: [.winter], logText: "一隻狐狸踩過雪地，回頭看了你一眼，走了。")
    ]

    /// 完整卡組（24 張起手）。擴充＝加卡即可，系統不改（`16` §3 末）。
    public static let all: [EncounterCard] = universal + spring + summer + autumn + winter

    /// 依季節過濾出當季可出現的卡（含通用卡）。
    public static func availableCards(for season: Season) -> [EncounterCard] {
        all.filter { $0.isAvailable(in: season) }
    }

    /// 確定性選卡（`16` §2.2）：先依季節過濾，再用 `hash(worldSeed, slotIndex) % filtered.count` 選一張。
    /// 若與「上一槽同 id」緊鄰重複則取次順位（環狀嘗試整個過濾後清單，避免死鎖）。
    /// **不依賴牆鐘**：同輸入永遠同輸出。空過濾清單時回傳 `nil`（防呆）。
    public static func card(atSlot slotIndex: Int, season: Season) -> EncounterCard? {
        let filtered = availableCards(for: season)
        guard !filtered.isEmpty else { return nil }
        guard filtered.count > 1 else { return filtered[0] }

        let previousCard = previousSlotCard(slotIndex: slotIndex, season: season, filtered: filtered)

        let baseIndex = Int(mix(worldSeed: worldSeed, slotIndex: slotIndex) % UInt64(filtered.count))
        for offset in 0..<filtered.count {
            let candidateIndex = (baseIndex + offset) % filtered.count
            let candidate = filtered[candidateIndex]
            if candidate.id != previousCard?.id {
                return candidate
            }
        }
        // 理論不可達（filtered.count > 1 保證至少有一張不同 id 的卡）。
        return filtered[baseIndex]
    }

    /// 計算「上一槽」在同一季節過濾清單下選出的卡，供避免緊鄰重複比較。
    /// 若上一槽落在不同季節（跨季交界），仍以「當下季節」的過濾清單重新選一次上一槽的結果——
    /// 這是刻意簡化：緊鄰重複的防呆本意是避免視覺上「同一句話連續出現」，用同一份過濾清單
    /// 重算上一槽索引即可達成，且維持確定性、無需額外狀態。
    private static func previousSlotCard(slotIndex: Int, season: Season, filtered: [EncounterCard]) -> EncounterCard? {
        guard slotIndex > 0, filtered.count > 1 else { return nil }
        let previousIndex = Int(mix(worldSeed: worldSeed, slotIndex: slotIndex - 1) % UInt64(filtered.count))
        return filtered[previousIndex]
    }

    /// 確定性整數混雜（splitmix64 風格，同 `Weather.kind(forEpochIndex:)` 範式）：
    /// 不需密碼學強度，只求分布均勻、對輸入敏感、不依賴牆鐘。
    private static func mix(worldSeed: UInt64, slotIndex: Int) -> UInt64 {
        var x = worldSeed &+ UInt64(bitPattern: Int64(slotIndex)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 33
        x = x &* 0xff51afd7ed558ccd
        x ^= x >> 33
        x = x &* 0xc4ceb9fe1a85ec53
        x ^= x >> 33
        return x
    }
}
