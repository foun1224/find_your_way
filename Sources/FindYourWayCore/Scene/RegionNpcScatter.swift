import Foundation

/// 純邏輯：各地域居民 NPC 的確定性槽位表（美術大改版第 3 波，`21_ASSET_OVERHAUL_PLAN.md` §3，
/// 泛用自 Stage B+ 的 `KingdomNpcScatter`——`02_PSYCHOLOGY_FOUNDATION.md` §2 社會臨場感，
/// 讓每個地域都「有人」而非只有王國）。不 import SpriteKit，`ParallaxBackground.buildNpcNodes`
/// 消費本型別算出的槽位 + `WorldScroll.wrappedX` 來畫，手法與 `PropScatter` 完全一致
/// （同一 `distance` 永遠得到同一畫面，純裝飾、不入 `GameState`、錯過無損、零功利）。
///
/// NPC 美術是**跨地域共享**的單一份檔案（`Resources/art/npc/<name>.png`，不放在各地域
/// `regions/<r>/npc/` 底下）——同一種 NPC（例如商人/旅人）會出現在不只一個地域，沒必要
/// 重複存檔；`slots(for:)` 只決定「這個地域出現哪些 NPC 型別 + 沿街位置」。
public enum RegionNpcScatter {

    /// 單一 NPC 槽位：`baseX` 落在 `[0, span)`，`npcName` 對應 `Resources/art/npc/<name>.png`。
    public struct Slot: Equatable {
        public let baseX: Double
        public let npcName: String

        public init(baseX: Double, npcName: String) {
            self.baseX = baseX
            self.npcName = npcName
        }
    }

    /// 循環週期（點）：與 `PropScatter.span` 同值，確保畫面永遠有居民覆蓋、不會忽然露出一片空城。
    public static let span: Double = 900

    /// 區域路人 NPC 是否渲染（使用者決定，2026-07-05：主角獨行世界先把沿街路人拿掉，
    /// 讓畫面更聚焦在旅人本身）。可逆旗標——`false` 時 `ParallaxBackground.buildNpcNodes`
    /// 直接不建任何 NPC 節點；槽位資料（`slots(for:)`/各 `*Slots`）原樣保留供測試與未來重啟，
    /// 只是不再被渲染（同 `GameScene.companionEnabled` 的休眠模式）。翻成 `true` 即恢復。
    public static let renderingEnabled = false

    /// 王國首都地域槽位表（沿用 Stage B+ 既有王國市民排法，士兵/衛兵隊長/貴族站崗巡邏交錯）——
    /// 美術大改版第 3 波把美術換成共享 `npc/` 資料夾裡的王室成員（`21` §3：國王/王后/公主/
    /// 大臣/騎士/衛兵）取代舊 `regions/kingdom/npc/{soldier,guard,noble}.png` 代表幀，
    /// 間距手法不變（比道具槽位疏落，維持 `02` §6 低喚醒的克制感）。
    public static let kingdomSlots: [Slot] = [
        Slot(baseX: 60, npcName: "guard"),
        Slot(baseX: 220, npcName: "minister"),
        Slot(baseX: 380, npcName: "knight"),
        Slot(baseX: 540, npcName: "queen"),
        Slot(baseX: 700, npcName: "king"),
        Slot(baseX: 830, npcName: "princess"),
    ]

    /// 田園地域（草原/村莊 A/村莊 B）共用槽位表（`21` §3）：農夫/麵包師/孩童/商人/樂手——
    /// 近人、日常感的田園村落人口。三個地域共用同一份排法（同款田園風格，`20` §0 世界觀鐵律）。
    public static let pastoralSlots: [Slot] = [
        Slot(baseX: 50, npcName: "farmer"),
        Slot(baseX: 220, npcName: "child"),
        Slot(baseX: 390, npcName: "baker"),
        Slot(baseX: 560, npcName: "merchant"),
        Slot(baseX: 730, npcName: "musician"),
    ]

    /// 港口海城地域槽位表（`21` §3；`seaCity` 已被 `harbor` 取代排出 8 地域循環，
    /// 槽位表原樣保留、休眠不刪）：漁夫/商人/旅人——碼頭往來的人口組成。
    public static let seaCitySlots: [Slot] = [
        Slot(baseX: 80, npcName: "fisher"),
        Slot(baseX: 320, npcName: "merchant"),
        Slot(baseX: 560, npcName: "traveler"),
    ]

    /// 海港地域槽位表（`20` §8A 驗證通過，`21` §2 第 3 波取代 `seaCity` 排進 8 地域循環）：
    /// 沿用原 `seaCitySlots` 的居民組成（漁夫/商人/旅人，碼頭往來的人口組成），
    /// 間距手法相同。
    public static let harborSlots: [Slot] = [
        Slot(baseX: 80, npcName: "fisher"),
        Slot(baseX: 320, npcName: "merchant"),
        Slot(baseX: 560, npcName: "traveler"),
    ]

    /// 天空地域（天空村莊/天空魔法城）共用槽位表（`21` §3）：學者/藥師/樂師——奇幻氛圍，
    /// 兩地域共用同一份排法（同款浮空奇幻風格）。
    public static let skySlots: [Slot] = [
        Slot(baseX: 100, npcName: "scholar"),
        Slot(baseX: 350, npcName: "apothecary"),
        Slot(baseX: 600, npcName: "musician"),
    ]

    /// 溫泉山村地域槽位表（接手任務：harbor 管線推廣到第二個 layered 地域，`21` §3）：
    /// 農夫/商人/旅人/藥師——山村往來的日常人口，混合田園（農夫）與旅途（商人/旅人）氛圍，
    /// 藥師呼應溫泉療養的意象。
    public static let hotspringVillageSlots: [Slot] = [
        Slot(baseX: 70, npcName: "farmer"),
        Slot(baseX: 300, npcName: "apothecary"),
        Slot(baseX: 530, npcName: "merchant"),
        Slot(baseX: 760, npcName: "traveler"),
    ]

    /// 仙俠山宮地域槽位表（接手任務：hotspring 管線推廣到第三個 layered 地域，`21` §3）：
    /// 學者/藥師/商人/旅人——沿用共享 `npc/` 資料夾裡最貼近「仙俠隱士」意象的既有角色
    /// （學者如問道求學的書生、藥師如採藥煉丹的方士），搭配商人/旅人維持人跡往來的氛圍，
    /// 與 `skySlots`（天空村莊/天空魔法城）同款人口組成但獨立排法，銜接兩者之間的過渡感。
    public static let mountainPalaceSlots: [Slot] = [
        Slot(baseX: 90, npcName: "scholar"),
        Slot(baseX: 330, npcName: "apothecary"),
        Slot(baseX: 570, npcName: "merchant"),
        Slot(baseX: 800, npcName: "traveler"),
    ]

    /// 雪山王國地域槽位表（接手任務：hotspring/mountain_palace 管線推廣到第四個 layered
    /// 地域，`21` §3）：旅人/商人/學者/藥師——沿用共享 `npc/` 資料夾裡最貼近「歐式中世紀
    /// 王國往來人跡」意象的既有角色（旅人如穿越雪山商道的行者，商人如駐守城門補給的貨商），
    /// 搭配學者/藥師維持奇幻氛圍，與 `hotspringVillageSlots` 同款人口組成但獨立排法，
    /// 銜接海港與天空村莊之間的過渡感。
    public static let snowMountainSlots: [Slot] = [
        Slot(baseX: 80, npcName: "traveler"),
        Slot(baseX: 310, npcName: "merchant"),
        Slot(baseX: 540, npcName: "scholar"),
        Slot(baseX: 770, npcName: "apothecary"),
    ]

    /// 浮空魔法之城地域槽位表（接手任務：hotspring/mountain_palace 管線推廣到第五個
    /// layered 地域，`21` §3）：學者/藥師/樂師/商人——與 `skySlots`（天空村莊/天空魔法城）
    /// 同款人口組成但獨立排法，銜接仙俠山宮與天空魔法城之間的過渡感，維持天界奇幻序列
    /// 一致的居民風格。
    public static let magicCitySlots: [Slot] = [
        Slot(baseX: 100, npcName: "scholar"),
        Slot(baseX: 350, npcName: "apothecary"),
        Slot(baseX: 600, npcName: "musician"),
        Slot(baseX: 830, npcName: "merchant"),
    ]

    /// 聖光之城地域槽位表（接手任務：magic_city 管線推廣到第六個 layered 地域，`21` §3）：
    /// 學者/藥師/樂師/商人——與 `magicCitySlots` 同款人口組成但獨立排法（重用既有共享
    /// `npc/` 角色，不新增美術），銜接浮空魔法之城與天空魔法城之間的過渡感，維持天界
    /// 奇幻序列一致的居民風格，收束在聖光之城的神聖氛圍。
    public static let holyCitySlots: [Slot] = [
        Slot(baseX: 100, npcName: "scholar"),
        Slot(baseX: 350, npcName: "apothecary"),
        Slot(baseX: 600, npcName: "musician"),
        Slot(baseX: 830, npcName: "merchant"),
    ]

    /// 蒸氣龐克飛船城地域槽位表（接手任務：holy_city 管線推廣到第七個 layered 地域，
    /// `21` §3）：旅人/商人/學者/藥師——與 `snowMountainSlots` 同款人口組成但獨立排法
    /// （重用既有共享 `npc/` 角色，不新增美術），銜接雪山王國與天空村莊之間的過渡感，
    /// 呼應飛船城作為工業貿易樞紐的居民風格。
    public static let steampunkCitySlots: [Slot] = [
        Slot(baseX: 80, npcName: "traveler"),
        Slot(baseX: 310, npcName: "merchant"),
        Slot(baseX: 540, npcName: "scholar"),
        Slot(baseX: 770, npcName: "apothecary"),
    ]

    /// 賽博龐克霓虹夜城地域槽位表（接手任務：steampunk_city 管線推廣到第八個 layered
    /// 地域，`21` §3）：旅人/商人/學者/藥師——與 `steampunkCitySlots` 同款人口組成但獨立
    /// 排法（重用既有共享 `npc/` 角色，不新增美術），銜接蒸氣龐克飛船城與天空村莊之間的
    /// 過渡感，呼應霓虹夜城作為另一座科技樞紐的居民風格，維持兩座科技城的人口組成一致。
    public static let futureCitySlots: [Slot] = [
        Slot(baseX: 80, npcName: "traveler"),
        Slot(baseX: 310, npcName: "merchant"),
        Slot(baseX: 540, npcName: "scholar"),
        Slot(baseX: 770, npcName: "apothecary"),
    ]

    /// 依地域挑選 NPC 槽位表（`21` §3「NPC → 地域分配」）：尚無美術的骨架地域
    /// （riverlands/highlands/coastalReach）回傳空陣列，保底邏輯同 `PropScatter`
    /// 對應 case（它們不在 `RegionType.at(bandIndex:)` 的循環裡，本來就不會被選到）。
    public static func slots(for region: RegionType) -> [Slot] {
        switch region {
        case .kingdom: return kingdomSlots
        case .meadowOrigin, .village3: return pastoralSlots
        case .seaCity: return seaCitySlots
        case .skyVillage, .skyCity: return skySlots
        case .riverlands, .highlands, .coastalReach: return []
        // 海港（`20` §8A 驗證通過，`21` §2 第 3 波取代 seaCity 排進循環）：居民組成見 `harborSlots`。
        case .harbor: return harborSlots
        // 溫泉山村（接手任務，harbor 管線推廣）：居民組成見 `hotspringVillageSlots`。
        case .hotspringVillage: return hotspringVillageSlots
        // 仙俠山宮（接手任務，hotspring 管線推廣）：居民組成見 `mountainPalaceSlots`。
        case .mountainPalace: return mountainPalaceSlots
        // 雪山王國（接手任務，hotspring/mountain_palace 管線推廣）：居民組成見 `snowMountainSlots`。
        case .snowMountain: return snowMountainSlots
        // 浮空魔法之城（接手任務，hotspring/mountain_palace 管線推廣）：居民組成見 `magicCitySlots`。
        case .magicCity: return magicCitySlots
        // 聖光之城（接手任務，magic_city 管線推廣）：居民組成見 `holyCitySlots`。
        case .holyCity: return holyCitySlots
        // 蒸氣龐克飛船城（接手任務，holy_city 管線推廣）：居民組成見 `steampunkCitySlots`。
        case .steampunkCity: return steampunkCitySlots
        // 賽博龐克霓虹夜城（接手任務，steampunk_city 管線推廣）：居民組成見 `futureCitySlots`。
        case .futureCity: return futureCitySlots
        }
    }

    /// NPC 層視差係數：與道具/地面同速（`layerFactor` 1.0），維持貼地錯覺。
    public static let layerFactor: Double = 1.0

    /// 計算某槽位在給定里程下的螢幕 x（沿用 `WorldScroll.wrappedX`，同 `PropScatter.screenX`）。
    public static func screenX(for slot: Slot, distance: Double) -> Double {
        WorldScroll.wrappedX(baseX: slot.baseX, distance: distance, layerFactor: layerFactor, span: span)
    }
}
