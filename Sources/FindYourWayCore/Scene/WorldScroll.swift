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
