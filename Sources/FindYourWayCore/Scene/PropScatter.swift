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

    /// 固定槽位表：間距與道具種類皆手動排定（確定性、可讀性優先於程式生成的隨機分佈）。
    /// 依 `baseX` 遞增排列。
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

    /// 道具層視差係數：與地面同速（`layerFactor` 1.0）或略慢，維持近景與地面貼合的錯覺。
    public static let layerFactor: Double = 1.0

    /// 計算某槽位在給定里程下的螢幕 x（沿用 `WorldScroll.wrappedX`）。
    public static func screenX(for slot: Slot, distance: Double) -> Double {
        WorldScroll.wrappedX(baseX: slot.baseX, distance: distance, layerFactor: layerFactor, span: span)
    }
}
