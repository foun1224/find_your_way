import Foundation

/// 純邏輯：里程 `distance` → 世界捲動偏移 / 地標螢幕位置（ADR-009 / `08` §3.8）。
/// 不 import SpriteKit/AppKit，`GameScene` 消費本型別的計算結果來畫。
///
/// 角色錨定於畫面左側固定位置、原地走路；世界（parallax 各層、地標）依累積里程向左捲動，
/// 表現「前進」。捲動量只由 `distance` 驅動，故 render 降頻/暫停不影響「走到哪」。
public enum WorldScroll {

    /// 角色固定的螢幕水平位置比例（ADR-009：畫面左側約 20–25%）。
    public static let characterScreenXRatio: Double = 0.22

    /// 角色固定的螢幕 x 座標（點）。
    public static func characterScreenX(sceneWidth: Double) -> Double {
        sceneWidth * characterScreenXRatio
    }

    /// 世界捲動偏移：`distance` 越大，偏移越往負方向（世界向左捲）。
    /// `layerFactor` 為視差係數：越接近 0（遠景）捲動越慢，越接近/大於 1（近景）捲動越快。
    public static func scrollOffset(forDistance distance: Double, layerFactor: Double) -> Double {
        -distance * layerFactor
    }

    /// 可循環佔位景物層的螢幕 x（`08` §4b）：景物依 `distance × layerFactor` 向左捲動，
    /// 移出畫面後 wrap 回收（週期 `span`），形成連續可見的運動。純裝飾、不入 `GameState`。
    ///
    /// 回傳值落在 `[0, span)`：`distance` 增加時值減少（往左移），到達 0 後 wrap 回 `span`（右側重入）。
    /// - Parameters:
    ///   - baseX: 該景物在單一週期內的基準槽位（`0..<span`）。
    ///   - span: 循環週期（點）；通常設為 ≥ 場景寬度 + 一格間距，確保畫面永遠有景物覆蓋。
    public static func wrappedX(baseX: Double, distance: Double, layerFactor: Double, span: Double) -> Double {
        guard span > 0 else { return baseX }
        let shifted = baseX - distance * layerFactor
        let m = shifted.truncatingRemainder(dividingBy: span)
        return m < 0 ? m + span : m
    }

    /// 地標在畫面上的 x 座標：以角色錨點 `characterAnchorX` 為基準，
    /// 隨 `currentDistance` 逼近而向左移入 → 抵達時對齊角色 → 通過後繼續往左移出畫面。
    public static func landmarkScreenX(
        landmarkDistance: Double,
        currentDistance: Double,
        characterAnchorX: Double
    ) -> Double {
        characterAnchorX + (landmarkDistance - currentDistance)
    }
}
