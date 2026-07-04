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
        EncounterCard(id: "kind_dog", category: .fauna, logText: "一隻狗跟了你們一小段，到牠家門口就停下了。"),

        // `17_ENCOUNTER_CARDS.md` §1（Fable curated · Accepted 2026-07-04）：通用卡 18 張。
        EncounterCard(id: "walk_shoulder_rest", category: .companion, logText: "走累了，你們肩並肩坐了一會兒，誰都沒開口。"),
        EncounterCard(id: "pebble_handed", category: .companion, logText: "他撿到一顆圓圓的石子，遞給你，你收進了口袋。"),
        EncounterCard(id: "wait_for_laces", category: .companion, logText: "你停下來繫鞋帶，他也停下，等你。"),
        EncounterCard(id: "last_ration_shared", category: .companion, logText: "分著吃最後一塊乾糧，誰也沒提剩得少。"),
        EncounterCard(id: "same_step_rhythm", category: .companion, logText: "你們並排走著，腳步不知不覺踩成了同一個節奏。"),
        EncounterCard(id: "tugged_sleeve", category: .companion, logText: "他先看見了什麼，沒說話，只是拉了拉你的袖子。"),
        EncounterCard(id: "bare_feet_airing", category: .companion, logText: "歇腳時，你們把靴子脫了，晾晾走了一天的腳。"),
        EncounterCard(id: "side_path", category: .scenery, logText: "一條小路從大路岔開，通向不知道哪裡，你們看了它一眼。"),
        EncounterCard(id: "puddles_after_rain", category: .scenery, logText: "雨後路上幾個小水窪，各自映著一小塊天。"),
        EncounterCard(id: "big_tree_flat_stone", category: .scenery, logText: "路口一棵大樹，樹下一塊給人歇腳的平石。"),
        EncounterCard(id: "cat_on_wall", category: .fauna, logText: "一隻貓從牆頭看你們經過，尾巴尖動了動。"),
        EncounterCard(id: "rustle_in_grass", category: .fauna, logText: "草叢裡有窸窣的聲音，你們放輕腳步，沒去驚動它。"),
        EncounterCard(id: "flower_in_wall_crack", category: .flora, logText: "石牆的縫裡鑽出一叢草，開著小小的花。"),
        EncounterCard(id: "dried_fruit_offered", category: .food, logText: "有人在門口曬果乾，招手讓你們各嚐了一顆。"),
        EncounterCard(id: "sweet_roadside_water", category: .food, logText: "路邊的水很甜，你們把水囊都灌滿了。"),
        EncounterCard(id: "distant_singing", category: .culture, logText: "遠處有人在唱歌，聽不真切，只覺得日子很慢。"),
        EncounterCard(id: "worn_doorstep", category: .culture, logText: "路過一戶人家，門前的石階被踩得凹了下去。"),
        EncounterCard(id: "laundry_in_wind", category: .culture, logText: "牆邊晾著誰家的衣服，在風裡輕輕地晃。")
    ]

    /// 春 Spring。
    private static let spring: [EncounterCard] = [
        EncounterCard(id: "first_buds", category: .flora, seasons: [.spring], logText: "枝頭冒出第一點綠，小心翼翼的樣子。"),
        EncounterCard(id: "spring_stream", category: .scenery, seasons: [.spring], logText: "雪水下山，溪聲比昨天響。"),
        EncounterCard(id: "nesting_birds", category: .fauna, seasons: [.spring], logText: "兩隻鳥在銜草築巢，忙得沒空理你。"),
        EncounterCard(id: "warm_bread", category: .food, seasons: [.spring], logText: "路過的村子在烤麵包，香味把你留了半刻。"),

        // `17_ENCOUNTER_CARDS.md` §2（Fable curated · Accepted 2026-07-04）：春卡 9 張。
        EncounterCard(id: "new_grass_ridge", category: .flora, seasons: [.spring], logText: "田埂上的野草冒了新綠，軟軟的一層。"),
        EncounterCard(id: "petals_on_shoulder", category: .flora, seasons: [.spring], logText: "一樹花開得滿，風一吹落了幾瓣在你們肩上。"),
        EncounterCard(id: "swallows_over_paddy", category: .fauna, seasons: [.spring], logText: "一群燕子低低地掠過水田。"),
        EncounterCard(id: "frogs_at_dusk", category: .fauna, seasons: [.spring], logText: "田裡有蛙聲，此起彼落，像在數著什麼。"),
        EncounterCard(id: "green_plums", category: .food, seasons: [.spring], logText: "路邊有人賣剛摘的青梅，酸得你們瞇了眼。"),
        EncounterCard(id: "snowmelt_field", category: .scenery, seasons: [.spring], logText: "融雪的田裡積了水，映著剛回暖的天。"),
        EncounterCard(id: "willow_buds", category: .scenery, seasons: [.spring], logText: "柳條垂到水面，剛抽出嫩黃的芽。"),
        EncounterCard(id: "sowing_seeds", category: .culture, seasons: [.spring], logText: "村口有人在翻土播種，彎著腰，不慌不忙。"),
        EncounterCard(id: "flower_tucked_on_pack", category: .companion, seasons: [.spring], logText: "他摘了朵路邊的花，別在你的包上，什麼也沒說。")
    ]

    /// 夏 Summer。
    private static let summer: [EncounterCard] = [
        EncounterCard(id: "cicada_noon", category: .fauna, seasons: [.summer], logText: "午後的蟬聲很滿，滿到讓人想找棵樹坐下。"),
        EncounterCard(id: "ripe_field", category: .flora, seasons: [.summer], logText: "一整片麥子熟了，風一過就是一片金色的浪。"),
        EncounterCard(id: "cold_well", category: .food, seasons: [.summer], logText: "井水冰涼，有人遞了你一瓢。"),
        EncounterCard(id: "long_shadow_evening", category: .scenery, seasons: [.summer], logText: "夏天的黃昏很長，影子拉得老遠。"),

        // `17_ENCOUNTER_CARDS.md` §3（Fable curated · Accepted 2026-07-04）：夏卡 9 張。
        EncounterCard(id: "heavy_green_shade", category: .flora, seasons: [.summer], logText: "路兩旁的樹綠得發沉，把太陽篩成一地碎光。"),
        EncounterCard(id: "sunflowers_facing", category: .flora, seasons: [.summer], logText: "向日葵整片朝著一個方向，你們也跟著看過去。"),
        EncounterCard(id: "dragonfly_on_tip", category: .fauna, seasons: [.summer], logText: "一隻蜻蜓停在草尖上，翅膀是透明的。"),
        EncounterCard(id: "fireflies", category: .fauna, seasons: [.summer], logText: "螢火蟲在草叢裡亮了一下，又暗了。"),
        EncounterCard(id: "watermelon_shared", category: .food, seasons: [.summer], logText: "樹下有人切開一顆西瓜，分了你們一角。"),
        EncounterCard(id: "afternoon_shower", category: .scenery, seasons: [.summer], logText: "午後起了一陣雷雨，你們躲在屋簷下，看它下完。"),
        EncounterCard(id: "river_haze_evening", category: .scenery, seasons: [.summer], logText: "傍晚的河面浮著暑氣，蜻蜓貼著水飛。"),
        EncounterCard(id: "evening_fan", category: .culture, seasons: [.summer], logText: "傍晚有人在門口搖著扇子乘涼，點頭跟你們打招呼。"),
        EncounterCard(id: "too_hot_to_move", category: .companion, seasons: [.summer], logText: "太熱了，你們找了棵樹，什麼也不做地坐了很久。")
    ]

    /// 秋 Autumn。
    private static let autumn: [EncounterCard] = [
        EncounterCard(id: "falling_leaves", category: .flora, seasons: [.autumn], logText: "葉子開始落了，踩上去有聲音。"),
        EncounterCard(id: "harvest_cart", category: .culture, seasons: [.autumn], logText: "一車剛收的果子經過，紅得發亮。"),
        EncounterCard(id: "roasted_chestnut", category: .food, seasons: [.autumn], logText: "街角在炒栗子，你買了一小袋，暖手。"),
        EncounterCard(id: "migrating_geese", category: .fauna, seasons: [.autumn], logText: "一行雁往南去，你抬頭看了很久。"),

        // `17_ENCOUNTER_CARDS.md` §4（Fable curated · Accepted 2026-07-04）：秋卡 8 張。
        EncounterCard(id: "silver_grass", category: .flora, seasons: [.autumn], logText: "路邊的芒草白了頭，風一過就伏成一片。"),
        EncounterCard(id: "squirrel_with_nut", category: .fauna, seasons: [.autumn], logText: "松鼠抱著顆果子，見了你們就竄上樹。"),
        EncounterCard(id: "slower_cricket", category: .fauna, seasons: [.autumn], logText: "一隻蟋蟀在牆角叫，聲音比夏天慢了些。"),
        EncounterCard(id: "grain_drying", category: .food, seasons: [.autumn], logText: "曬場上鋪滿了金黃的穀子，香味乾乾的。"),
        EncounterCard(id: "ripe_persimmons", category: .scenery, seasons: [.autumn], logText: "柿子紅透了掛在枝上，葉子快落光了。"),
        EncounterCard(id: "orange_dusk_clouds", category: .scenery, seasons: [.autumn], logText: "起風的傍晚，天邊的雲被染成了橘紅。"),
        EncounterCard(id: "corn_under_eaves", category: .culture, seasons: [.autumn], logText: "有人把玉米一串串地掛上了屋簷。"),
        EncounterCard(id: "leaf_kept", category: .companion, seasons: [.autumn], logText: "他撿起一片好看的葉子，夾進了行囊裡。")
    ]

    /// 冬 Winter：安靜乾淨的白，不做蕭瑟/死亡壓力（`16` §1.2）。
    private static let winter: [EncounterCard] = [
        EncounterCard(id: "first_snow", category: .scenery, seasons: [.winter], logText: "今年的第一場雪，很輕，落在肩上就化了。"),
        EncounterCard(id: "frozen_pond", category: .scenery, seasons: [.winter], logText: "池面結了薄冰，映著乾淨的天。"),
        EncounterCard(id: "warm_soup", category: .food, seasons: [.winter], logText: "有人請你喝了碗熱湯，說了句你聽不懂但很暖的話。"),
        EncounterCard(id: "fox_in_snow", category: .fauna, seasons: [.winter], logText: "一隻狐狸踩過雪地，回頭看了你一眼，走了。"),

        // `17_ENCOUNTER_CARDS.md` §5（Fable curated · Accepted 2026-07-04）：冬卡 8 張。
        EncounterCard(id: "snow_on_rooftops", category: .scenery, seasons: [.winter], logText: "屋頂積了薄薄一層白，煙囪冒著直直的煙。"),
        EncounterCard(id: "two_lines_of_footprints", category: .scenery, seasons: [.winter], logText: "田野一片安靜的白，只有你們兩行腳印。"),
        EncounterCard(id: "winter_plum", category: .flora, seasons: [.winter], logText: "牆角一株梅開了，冷冷的，很香。"),
        EncounterCard(id: "sparrows_puffed", category: .fauna, seasons: [.winter], logText: "幾隻麻雀擠在光禿的枝上，蓬成小小的球。"),
        EncounterCard(id: "cat_in_winter_sun", category: .fauna, seasons: [.winter], logText: "一隻貓縮在誰家的窗台上，曬那一點冬天的太陽。"),
        EncounterCard(id: "steaming_buns", category: .food, seasons: [.winter], logText: "路過的攤子蒸著白胖的包子，熱氣糊了半條街。"),
        EncounterCard(id: "new_red_paper", category: .culture, seasons: [.winter], logText: "家家門上換了新的紅紙，路過都覺得暖。"),
        EncounterCard(id: "scarf_pulled_up", category: .companion, seasons: [.winter], logText: "你們哈著白氣走，他把圍巾往上拉了拉。")
    ]

    /// 完整卡組（24 張起手 + `17_ENCOUNTER_CARDS.md` 52 張 = 76 張）。擴充＝加卡即可，系統不改（`16` §3 末）。
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
