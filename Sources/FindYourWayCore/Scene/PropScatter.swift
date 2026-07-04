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

    /// 草原地域固定槽位表（Phase 4b；`18_STAGE_B_SPEC.md` §1 地域化後為 `meadow` 地域專用）：
    /// 間距與道具種類皆手動排定（確定性、可讀性優先於程式生成的隨機分佈）。依 `baseX` 遞增排列。
    /// 保留 `slots` 這個名字（而非改名 `meadowSlots`）：既有呼叫端/測試（`PropScatterTests`）
    /// 直接讀這個屬性，重新命名沒有額外好處、只會增加不必要的 churn。
    public static let slots: [Slot] = [
        Slot(baseX: 40, propName: "bush"),
        Slot(baseX: 150, propName: "rock"),
        Slot(baseX: 250, propName: "grass"),
        Slot(baseX: 340, propName: "fence"),
        Slot(baseX: 480, propName: "haystack"),
        Slot(baseX: 600, propName: "flower"),
        Slot(baseX: 700, propName: "barrel_small"),
        Slot(baseX: 800, propName: "crate_medium"),
    ]

    /// 王國首都地域槽位表（`18` §1/§3，`19_STAGE_C_SPEC.md` §1 王國環境重切後更新）：
    /// 道具池換成新版 `design/kingdom.png` 道具列實際切出的王國道具（`regions/kingdom/props/`）。
    /// 舊版（`bench`/`signpost`/`market_stall`/`statue`/`tree`/`fountain`/`potted_flower`）已隨
    /// Stage C 重切作廢——新 kingdom.png 的道具列裡沒有這些物件，繼續引用會讀到 Stage B 遺留的
    /// 舊風格靜態檔案（未隨新素材重切、風格不搭），因此全面換成新素材表實際切出的 10 種道具。
    /// 間距手法同 `slots`（確定性、依 `baseX` 遞增排列，均勻散佈在同一個 `span` 週期內）。
    public static let kingdomSlots: [Slot] = [
        Slot(baseX: 40, propName: "lamppost"),
        Slot(baseX: 122, propName: "planter"),
        Slot(baseX: 204, propName: "pillar"),
        Slot(baseX: 286, propName: "fence_low"),
        Slot(baseX: 368, propName: "banner"),
        Slot(baseX: 450, propName: "crate"),
        Slot(baseX: 532, propName: "crate_reinforced"),
        Slot(baseX: 614, propName: "barrel"),
        Slot(baseX: 696, propName: "fence"),
        Slot(baseX: 778, propName: "cart"),
    ]

    /// 港口海城地域槽位表（`19_STAGE_C_SPEC.md` §1/§3，第三地域）：道具池換成
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

    /// 依地域挑選道具槽位表（`18` §3 / `19` §3「道具 scatter 依當前地域選該地域的道具池」）。
    /// 尚無專屬槽位表的骨架地域退回 `slots`（meadow），與 `RegionType.assetFolder` 同一保底邏輯。
    public static func slots(for region: RegionType) -> [Slot] {
        switch region {
        case .kingdom: return kingdomSlots
        case .seaCity: return seaCitySlots
        case .meadowOrigin, .riverlands, .highlands, .coastalReach: return slots
        }
    }

    /// 道具層視差係數：與地面同速（`layerFactor` 1.0）或略慢，維持近景與地面貼合的錯覺。
    public static let layerFactor: Double = 1.0

    /// 計算某槽位在給定里程下的螢幕 x（沿用 `WorldScroll.wrappedX`）。
    public static func screenX(for slot: Slot, distance: Double) -> Double {
        WorldScroll.wrappedX(baseX: slot.baseX, distance: distance, layerFactor: layerFactor, span: span)
    }
}
