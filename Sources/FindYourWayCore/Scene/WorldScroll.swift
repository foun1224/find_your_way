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

    /// Panorama 無縫水平平鋪（`08` §4b / Phase 4a 修正）：與 `wrappedX`（供未來近景散落道具 scatter 用）不同，
    /// panorama 是一整條連續背景，必須保證任意 `distance` 下 `[0, sceneWidth]` 都被完整覆蓋、無縫。
    ///
    /// 作法：把 `distance * layerFactor` 對 `tileWidth` 取模得到 `[0, tileWidth)` 的偏移 `offset`，
    /// 再鋪出足夠多張、左緣落在 `i * tileWidth - offset`（`i = 0..<count`）的 tile。
    /// 因為 `offset < tileWidth`，第 0 張的左緣落在 `(-tileWidth, 0]`，只要張數涵蓋到
    /// `sceneWidth + tileWidth`，聯集必然覆蓋整個可視範圍，且相鄰 tile 緊鄰（無縫）。
    /// - Returns: 各 tile 左緣（anchor 在左下）的 x 座標，由左到右排列。
    public static func panoramaTileXs(
        sceneWidth: Double,
        tileWidth: Double,
        distance: Double,
        layerFactor: Double
    ) -> [Double] {
        guard tileWidth > 0 else { return [] }

        let shift = distance * layerFactor
        let rawOffset = shift.truncatingRemainder(dividingBy: tileWidth)
        let offset = rawOffset < 0 ? rawOffset + tileWidth : rawOffset

        // +2：一張補左邊（offset 造成第 0 張左移）、一張補右邊（無條件進位的餘量），
        // 確保 [0, sceneWidth] 兩端都仍有 tile 覆蓋。
        let count = Int((sceneWidth / tileWidth).rounded(.up)) + 2
        return (0..<count).map { Double($0) * tileWidth - offset }
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
