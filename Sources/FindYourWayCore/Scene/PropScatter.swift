import Foundation

/// 純邏輯：近景道具散佈的確定性槽位表（Phase 4b，`12_PHASE4_SPEC.md` §2/§6）。
/// 不 import SpriteKit，`GameScene` 消費本型別算出的槽位 + `WorldScroll.wrappedX` 來畫。
///
/// **確定性**（`09` §2.2 B 類氛圍裝飾）：槽位與道具種類是固定表，不是每幀隨機——
/// 同一個 `distance` 永遠得到同一個畫面，純裝飾、不入 `GameState`、錯過無損。
/// 沿用 `WorldScroll.wrappedX`（散落小物件的既有正確工具，見其註解），
/// 而非 `panoramaTileXs`（那是給連續一整條背景用的）。
public enum PropScatter {

    /// 單一道具槽位：`baseX` 落在 `[0, span)`，`propName` 對應 `Resources/art/props/<name>.png`。
    public struct Slot: Equatable {
        public let baseX: Double
        public let propName: String

        public init(baseX: Double, propName: String) {
            self.baseX = baseX
            self.propName = propName
        }
    }

    /// 循環週期（點）：需 ≥ 一般場景寬度，確保畫面永遠有道具覆蓋、不會忽然露出一片空。
    public static let span: Double = 900

    /// 草原地域固定槽位表（Phase 4b；`18_STAGE_B_SPEC.md` §1 地域化後為 `meadow`/`grassland`
    /// 地域專用；美術大改版第 1 波 `21_ASSET_OVERHAUL_PLAN.md` §4 換成 `design/grassland.png`
    /// 切出的新道具池，取代舊 `asset_sheet.png` 道具）：
    /// 間距與道具種類皆手動排定（確定性、可讀性優先於程式生成的隨機分佈）。依 `baseX` 遞增排列。
    /// 保留 `slots` 這個名字（而非改名 `grasslandSlots`）：既有呼叫端/測試（`PropScatterTests`）
    /// 直接讀這個屬性，重新命名沒有額外好處、只會增加不必要的 churn。
    public static let slots: [Slot] = [
        Slot(baseX: 40, propName: "tree"),
        Slot(baseX: 130, propName: "signpost"),
        Slot(baseX: 210, propName: "well"),
        Slot(baseX: 300, propName: "banner"),
        Slot(baseX: 380, propName: "haycart"),
        Slot(baseX: 470, propName: "planter"),
        Slot(baseX: 550, propName: "barrel"),
        Slot(baseX: 630, propName: "market_stall"),
        Slot(baseX: 730, propName: "crate"),
        Slot(baseX: 810, propName: "windmill"),
        Slot(baseX: 870, propName: "monolith"),
    ]

    /// 王國首都地域槽位表（`18` §1/§3 → `19_STAGE_C_SPEC.md` §1 → 美術大改版第 2 波
    /// `21_ASSET_OVERHAUL_PLAN.md` §4 再次重切）：道具池換成新版 1536x1024
    /// `design/kingdom.png` 道具列實際切出的王國道具（`regions/kingdom/props/`）。
    /// 舊版（`fence_low`/`crate_reinforced`/`fence`/`planter`）已隨本波重切作廢——新版
    /// kingdom.png 的道具列裡沒有這些物件，繼續引用會讀不到檔案（優雅降級為不顯示、
    /// 但畫面會少道具），因此全面換成新素材表實際切出的 11 種道具。
    /// 間距手法同 `slots`（確定性、依 `baseX` 遞增排列，均勻散佈在同一個 `span` 週期內）。
    public static let kingdomSlots: [Slot] = [
        Slot(baseX: 40, propName: "banner"),
        Slot(baseX: 115, propName: "lamppost"),
        Slot(baseX: 190, propName: "tree"),
        Slot(baseX: 265, propName: "lion"),
        Slot(baseX: 340, propName: "fountain"),
        Slot(baseX: 415, propName: "cart"),
        Slot(baseX: 490, propName: "crate"),
        Slot(baseX: 565, propName: "angel"),
        Slot(baseX: 640, propName: "signboard"),
        Slot(baseX: 715, propName: "pillar"),
        Slot(baseX: 790, propName: "dome"),
    ]

    /// 村莊 B 地域槽位表（美術大改版第 2 波）：道具池為 `regions/village_3/props/`
    /// （森林樹屋村落：蘑菇樹墩燈/繩橋/水晶井等），間距手法同 `slots`。
    public static let village3Slots: [Slot] = [
        Slot(baseX: 40, propName: "tree"),
        Slot(baseX: 115, propName: "lamppost"),
        Slot(baseX: 190, propName: "signpost"),
        Slot(baseX: 265, propName: "bench"),
        Slot(baseX: 340, propName: "market_stall"),
        Slot(baseX: 415, propName: "barrel"),
        Slot(baseX: 490, propName: "crate"),
        Slot(baseX: 565, propName: "planter"),
        Slot(baseX: 640, propName: "stump_lantern"),
        Slot(baseX: 715, propName: "bridge"),
        Slot(baseX: 790, propName: "crystal_well"),
    ]

    /// 天空村莊地域槽位表（美術大改版第 2 波）：道具池為 `regions/sky_village/props/`
    /// （浮空平台迴廊：噴泉/飛船/水晶柱等），間距手法同 `slots`。
    public static let skyVillageSlots: [Slot] = [
        Slot(baseX: 40, propName: "tree"),
        Slot(baseX: 108, propName: "pillar"),
        Slot(baseX: 176, propName: "lamppost"),
        Slot(baseX: 244, propName: "signpost"),
        Slot(baseX: 312, propName: "planter"),
        Slot(baseX: 380, propName: "fountain"),
        Slot(baseX: 448, propName: "crate"),
        Slot(baseX: 516, propName: "barrel"),
        Slot(baseX: 584, propName: "banner_post"),
        Slot(baseX: 652, propName: "airship"),
        Slot(baseX: 720, propName: "crystal_pillar"),
        Slot(baseX: 788, propName: "fence"),
    ]

    /// 天空魔法城地域槽位表（美術大改版第 2 波）：道具池為 `regions/sky_city/props/`
    /// （金色魔法水晶城：魔法鏡/寶箱/魔法拱門等），間距手法同 `slots`。
    public static let skyCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "crystal_fountain"),
        Slot(baseX: 108, propName: "pillar"),
        Slot(baseX: 176, propName: "banner_post"),
        Slot(baseX: 244, propName: "lamp"),
        Slot(baseX: 312, propName: "planter"),
        Slot(baseX: 380, propName: "market_stall"),
        Slot(baseX: 448, propName: "mirror"),
        Slot(baseX: 516, propName: "chest"),
        Slot(baseX: 584, propName: "crystal"),
        Slot(baseX: 652, propName: "signpost"),
        Slot(baseX: 720, propName: "airship"),
        Slot(baseX: 788, propName: "gate"),
    ]

    /// 港口海城地域槽位表（`19_STAGE_C_SPEC.md` §1/§3，第三地域；已被 `harbor` 取代排出
    /// 8 地域循環，`21` §2 第 3 波，但槽位表原樣保留、休眠不刪）：道具池換成
    /// `regions/sea_city/props/` 切出的海城道具（含碼頭特有的繫纜柱/吊車），
    /// 間距手法同 `slots`/`kingdomSlots`（確定性、依 `baseX` 遞增排列）。
    public static let seaCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "lamppost"),
        Slot(baseX: 110, propName: "bollard"),
        Slot(baseX: 190, propName: "banner"),
        Slot(baseX: 280, propName: "crate"),
        Slot(baseX: 360, propName: "barrel"),
        Slot(baseX: 440, propName: "crane"),
        Slot(baseX: 540, propName: "crate_sack"),
        Slot(baseX: 630, propName: "planter"),
        Slot(baseX: 710, propName: "fence"),
        Slot(baseX: 800, propName: "pillar"),
    ]

    /// 海港地域槽位表（`20_ASSET_SHEET_SPEC.md` §8A 驗證通過，`21` §2 第 3 波取代
    /// `seaCity` 排進 8 地域循環）：道具池換成 `regions/harbor/props/` 切出的港口道具
    /// （沿街市集攤車/水岸標示/繫船錨牌等），間距手法同 `seaCitySlots`
    /// （確定性、依 `baseX` 遞增排列，均勻散佈在同一個 `span` 週期內）。
    public static let harborSlots: [Slot] = [
        Slot(baseX: 40, propName: "signpost"),
        Slot(baseX: 130, propName: "lamp"),
        Slot(baseX: 220, propName: "anchor_sign"),
        Slot(baseX: 320, propName: "barrel"),
        Slot(baseX: 420, propName: "market_cart"),
        Slot(baseX: 520, propName: "planter"),
    ]

    /// 溫泉山村地域槽位表（接手任務：harbor 管線推廣到第二個 layered 地域，`21` §2/§4）：
    /// 道具池換成 `regions/hotspring_village/props/` 切出的日式溫泉山村道具（櫻花樹/石燈籠/
    /// 溫泉旗幡/岩石噴泉等），間距手法同 `harborSlots`（確定性、依 `baseX` 遞增排列）。
    public static let hotspringVillageSlots: [Slot] = [
        Slot(baseX: 40, propName: "cherry_tree"),
        Slot(baseX: 130, propName: "stone_lantern"),
        Slot(baseX: 220, propName: "signpost"),
        Slot(baseX: 310, propName: "onsen_banner"),
        Slot(baseX: 400, propName: "hotspring_rock"),
        Slot(baseX: 490, propName: "market_stall"),
    ]

    /// 仙俠山宮地域槽位表（接手任務：hotspring 管線推廣到第三個 layered 地域，`21` §2/§4）：
    /// 道具池換成 `regions/mountain_palace/props/` 切出的仙俠山宮道具（仙鶴石像/石燈籠/
    /// 仙字幡旗燈/盆栽奇石/香爐/石碑等），間距手法同 `hotspringVillageSlots`（確定性、依
    /// `baseX` 遞增排列）。
    public static let mountainPalaceSlots: [Slot] = [
        Slot(baseX: 40, propName: "crane_statue"),
        Slot(baseX: 130, propName: "stone_lantern"),
        Slot(baseX: 220, propName: "immortal_banner"),
        Slot(baseX: 310, propName: "bonsai_rock"),
        Slot(baseX: 400, propName: "incense_burner"),
        Slot(baseX: 490, propName: "stone_stele"),
    ]

    /// 雪山王國地域槽位表（接手任務：hotspring/mountain_palace 管線推廣到第四個 layered
    /// 地域，`21` §2/§4）：道具池換成 `regions/snow_mountain/props/` 切出的歐式中世紀奇幻
    /// 雪山王國道具（雪松/紋章旗/火把石柱/雪堆石堆/符文石碑等），間距手法同
    /// `mountainPalaceSlots`（確定性、依 `baseX` 遞增排列）。
    public static let snowMountainSlots: [Slot] = [
        Slot(baseX: 40, propName: "snow_pine"),
        Slot(baseX: 130, propName: "heraldic_banner"),
        Slot(baseX: 220, propName: "torch_pillar"),
        Slot(baseX: 310, propName: "snow_cairn"),
        Slot(baseX: 400, propName: "rune_stele"),
        Slot(baseX: 490, propName: "wooden_fence"),
    ]

    /// 浮空魔法之城地域槽位表（接手任務：hotspring/mountain_palace 管線推廣到第五個
    /// layered 地域，`21` §2/§4）：道具池換成 `regions/magic_city/props/` 切出的漂浮魔法
    /// 之城道具（水晶噴泉座/符文紋章旗/水晶柱座/望遠鏡/符文法輪等），間距手法同
    /// `mountainPalaceSlots`（確定性、依 `baseX` 遞增排列）。
    public static let magicCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "crystal_shard"),
        Slot(baseX: 130, propName: "arcane_banner"),
        Slot(baseX: 220, propName: "crystal_pillar"),
        Slot(baseX: 310, propName: "flower_urn"),
        Slot(baseX: 400, propName: "telescope"),
        Slot(baseX: 490, propName: "arcane_wheel"),
    ]

    /// 聖光之城地域槽位表（接手任務：magic_city 管線推廣到第六個 layered 地域，`21` §2/§4）：
    /// 道具池換成 `regions/holy_city/props/` 切出的歐式高奇幻聖光之城道具（十字紋章旗/
    /// 天使雕像/花卉水甕/石長椅/噴泉/燭台等），間距手法同 `magicCitySlots`（確定性、依
    /// `baseX` 遞增排列）。
    public static let holyCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "cross_banner"),
        Slot(baseX: 130, propName: "angel_statue"),
        Slot(baseX: 220, propName: "flower_urn"),
        Slot(baseX: 310, propName: "stone_bench"),
        Slot(baseX: 400, propName: "fountain"),
        Slot(baseX: 490, propName: "candelabra"),
    ]

    /// 蒸氣龐克飛船城地域槽位表（接手任務：holy_city 管線推廣到第七個 layered 地域，
    /// `21` §2/§4）：道具池換成 `regions/steampunk_city/props/` 切出的黃銅飛船城道具
    /// （瓦斯燈/指路牌/木箱/木桶/齒輪引擎/黃銅望遠鏡等），間距手法同 `holyCitySlots`
    /// （確定性、依 `baseX` 遞增排列）。
    public static let steampunkCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "gas_lamp"),
        Slot(baseX: 130, propName: "signpost"),
        Slot(baseX: 220, propName: "crate"),
        Slot(baseX: 310, propName: "barrel"),
        Slot(baseX: 400, propName: "gear_engine"),
        Slot(baseX: 490, propName: "brass_telescope"),
    ]

    /// 賽博龐克霓虹夜城地域槽位表（接手任務：steampunk_city 管線推廣到第八個 layered
    /// 地域，`21` §2/§4）：道具池換成 `regions/future_city/props/` 切出的賽博龐克霓虹夜城
    /// 道具（全息廣告牌/街燈/全息地球儀/發光水晶/無人機/霓虹櫻花盆栽等），間距手法同
    /// `steampunkCitySlots`（確定性、依 `baseX` 遞增排列）。
    public static let futureCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "holo_billboard"),
        Slot(baseX: 130, propName: "street_lamp"),
        Slot(baseX: 220, propName: "hologram_globe"),
        Slot(baseX: 310, propName: "crystal"),
        Slot(baseX: 400, propName: "drone"),
        Slot(baseX: 490, propName: "neon_tree"),
    ]

    /// 中世紀奇幻村莊地域槽位表（接手任務：`meadowOrigin` 重新指回 layered 美術，`21` §2/§4，
    /// holy_city 管線推廣）：道具池換成 `regions/meadow_village/props/` 切出的歐式中世紀
    /// 奇幻村莊道具（路燈/指路牌/花卉推車/曬衣繩/矮石牆/十字聖壇等），間距手法同
    /// `holyCitySlots`（確定性、依 `baseX` 遞增排列）。
    public static let meadowVillageSlots: [Slot] = [
        Slot(baseX: 40, propName: "lamp_post"),
        Slot(baseX: 130, propName: "signpost"),
        Slot(baseX: 220, propName: "flower_cart"),
        Slot(baseX: 310, propName: "laundry_line"),
        Slot(baseX: 400, propName: "stone_wall"),
        Slot(baseX: 490, propName: "cross_shrine"),
    ]

    /// 王國首都地域槽位表（接手任務：`RegionType.kingdom` 重新指回 layered 美術，`21` §2/§4，
    /// meadow_village/holy_city 管線推廣）：道具池換成 `regions/kingdom_city/props/` 切出的
    /// 歐式白金王國首都道具（紋章旗幟/花卉甕/盆栽柏樹/告示牌/石柱等），間距手法同
    /// `holyCitySlots`（確定性、依 `baseX` 遞增排列）。取代舊 `kingdomSlots`
    /// （對應舊 `"kingdom"` 單張背景的道具池，已停用、原樣保留供未來重啟參考）。
    public static let kingdomCitySlots: [Slot] = [
        Slot(baseX: 40, propName: "heraldic_banner"),
        Slot(baseX: 130, propName: "lamp_post"),
        Slot(baseX: 220, propName: "flower_urn"),
        Slot(baseX: 310, propName: "cypress"),
        Slot(baseX: 400, propName: "stone_bench"),
        Slot(baseX: 490, propName: "notice_board"),
    ]

    /// 森林樹屋村落地域槽位表（接手任務：`RegionType.village3` 重新指回 layered 美術，
    /// `21` §2/§4，meadow_village/holy_city 管線推廣）：道具池換成 `regions/tree_village/props/`
    /// 切出的森林樹屋村落道具（旗幡/花卉推車/曬衣繩/圓形徽章告示/拱門等），間距手法同
    /// `holyCitySlots`（確定性、依 `baseX` 遞增排列）。取代舊 `village3Slots`
    /// （對應舊 `"village_3"` 單張背景的道具池，已停用、原樣保留供未來重啟參考）。
    public static let treeVillageSlots: [Slot] = [
        Slot(baseX: 40, propName: "lamp_post"),
        Slot(baseX: 130, propName: "banner"),
        Slot(baseX: 220, propName: "flower_cart"),
        Slot(baseX: 310, propName: "laundry_line"),
        Slot(baseX: 400, propName: "round_sign"),
        Slot(baseX: 490, propName: "arch_gate"),
    ]

    /// 白金浮空天空之城地域槽位表（接手任務：`RegionType.skyCity` 重新指回 layered 美術，
    /// `21` §2/§4，meadow_village/kingdom_city 管線推廣）：道具池換成 `regions/sky_city_v2/props/`
    /// 切出的白金浮空天空之城道具（水晶/噴泉/寶箱/路燈/告示牌/旗幟等），間距手法同
    /// `kingdomCitySlots`（確定性、依 `baseX` 遞增排列）。取代舊 `skyCitySlots`
    /// （對應舊 `"sky_city"` 單張背景的道具池，已停用、原樣保留供未來重啟參考）。
    public static let skyCityV2Slots: [Slot] = [
        Slot(baseX: 40, propName: "lamp_post"),
        Slot(baseX: 130, propName: "banner"),
        Slot(baseX: 220, propName: "crystal"),
        Slot(baseX: 310, propName: "fountain"),
        Slot(baseX: 400, propName: "chest"),
        Slot(baseX: 490, propName: "notice_board"),
    ]

    /// 浮空天空村地域槽位表（接手任務：`RegionType.skyVillage` 重新指回 layered 美術，
    /// `21` §2/§4，sky_city_v2/kingdom_city 管線推廣）：道具池換成 `regions/sky_village_v2/props/`
    /// 切出的浮空天空村道具（路燈/長椅/花車/水井/告示牌/盆栽小樹等），間距手法同
    /// `skyCityV2Slots`（確定性、依 `baseX` 遞增排列）。取代舊 `skyVillageSlots`
    /// （對應舊 `"sky_village"` 單張背景的道具池，已停用、原樣保留供未來重啟參考）。
    public static let skyVillageV2Slots: [Slot] = [
        Slot(baseX: 40, propName: "lamp_post"),
        Slot(baseX: 130, propName: "signpost"),
        Slot(baseX: 220, propName: "well"),
        Slot(baseX: 310, propName: "bench"),
        Slot(baseX: 400, propName: "flower_cart"),
        Slot(baseX: 490, propName: "notice_board"),
    ]

    /// 依地域挑選道具槽位表（`18` §3 / `19` §3「道具 scatter 依當前地域選該地域的道具池」）。
    /// 尚無專屬槽位表的骨架地域退回 `slots`（meadow），與 `RegionType.assetFolder` 同一保底邏輯。
    public static func slots(for region: RegionType) -> [Slot] {
        switch region {
        // 王國首都（接手任務，重新指回 layered 美術）：道具池見 `kingdomCitySlots`。
        case .kingdom: return kingdomCitySlots
        case .seaCity: return seaCitySlots
        // 中世紀奇幻村莊（接手任務，重新指回 layered 美術，開場地域）：道具池見 `meadowVillageSlots`。
        case .meadowOrigin: return meadowVillageSlots
        case .riverlands, .highlands, .coastalReach: return slots
        // 森林樹屋村落（接手任務，重新指回 layered 美術）：道具池見 `treeVillageSlots`。
        case .village3: return treeVillageSlots
        // 浮空天空村（接手任務，重新指回 layered 美術）：道具池見 `skyVillageV2Slots`。
        case .skyVillage: return skyVillageV2Slots
        // 白金浮空天空之城（接手任務，重新指回 layered 美術，壓軸地域）：道具池見 `skyCityV2Slots`。
        case .skyCity: return skyCityV2Slots
        // 海港（`20` §8A 驗證通過，`21` §2 第 3 波取代 seaCity 排進循環）：道具池見 `harborSlots`。
        case .harbor: return harborSlots
        // 溫泉山村（接手任務，harbor 管線推廣）：道具池見 `hotspringVillageSlots`。
        case .hotspringVillage: return hotspringVillageSlots
        // 仙俠山宮（接手任務，hotspring 管線推廣）：道具池見 `mountainPalaceSlots`。
        case .mountainPalace: return mountainPalaceSlots
        // 雪山王國（接手任務，hotspring/mountain_palace 管線推廣）：道具池見 `snowMountainSlots`。
        case .snowMountain: return snowMountainSlots
        // 浮空魔法之城（接手任務，hotspring/mountain_palace 管線推廣）：道具池見 `magicCitySlots`。
        case .magicCity: return magicCitySlots
        // 聖光之城（接手任務，magic_city 管線推廣）：道具池見 `holyCitySlots`。
        case .holyCity: return holyCitySlots
        // 蒸氣龐克飛船城（接手任務，holy_city 管線推廣）：道具池見 `steampunkCitySlots`。
        case .steampunkCity: return steampunkCitySlots
        // 賽博龐克霓虹夜城（接手任務，steampunk_city 管線推廣）：道具池見 `futureCitySlots`。
        case .futureCity: return futureCitySlots
        }
    }

    /// 道具層視差係數：與地面同速（`layerFactor` 1.0）或略慢，維持近景與地面貼合的錯覺。
    public static let layerFactor: Double = 1.0

    /// 計算某槽位在給定里程下的螢幕 x（沿用 `WorldScroll.wrappedX`）。
    public static func screenX(for slot: Slot, distance: Double) -> Double {
        WorldScroll.wrappedX(baseX: slot.baseX, distance: distance, layerFactor: layerFactor, span: span)
    }
}
