import Foundation

/// 純邏輯：王國首都地域的市民 NPC 確定性槽位表（Stage B+，`02_PSYCHOLOGY_FOUNDATION.md` §2
/// 社會臨場感——讓王國從空城變「有人的活城市」）。不 import SpriteKit，`GameScene`/`ParallaxBackground`
/// 消費本型別算出的槽位 + `WorldScroll.wrappedX` 來畫，手法與 `PropScatter` 完全一致
/// （同一 `distance` 永遠得到同一畫面，純裝飾、不入 `GameState`、錯過無損、零功利）。
///
/// 只有王國地域有市民（草原是荒野，本就沒有城市人口）：`slots(for:)` 對非王國地域回傳空陣列，
/// 呼叫端（`ParallaxBackground.buildRegion`）依此自然地在草原不放任何 NPC 節點。
public enum KingdomNpcScatter {

    /// 單一 NPC 槽位：`baseX` 落在 `[0, span)`，`npcName` 對應
    /// `Resources/art/regions/kingdom/npc/<name>.png`。
    public struct Slot: Equatable {
        public let baseX: Double
        public let npcName: String

        public init(baseX: Double, npcName: String) {
            self.baseX = baseX
            self.npcName = npcName
        }
    }

    /// 循環週期（點）：與 `PropScatter.span` 同值，確保畫面永遠有市民覆蓋、不會忽然露出一片空城。
    public static let span: Double = 900

    /// 王國首都市民槽位表：士兵站崗、衛兵隊長巡邏、貴族/公主散步——三種角色交錯排列，
    /// 間距刻意疏落（比道具槽位稀，避免畫面塞爆、維持低喚醒 `02` §6 的克制感）。
    /// 依 `baseX` 遞增排列。
    public static let kingdomSlots: [Slot] = [
        Slot(baseX: 60, npcName: "soldier"),
        Slot(baseX: 260, npcName: "noble"),
        Slot(baseX: 460, npcName: "guard"),
        Slot(baseX: 660, npcName: "soldier"),
    ]

    /// 依地域挑選 NPC 槽位表：只有王國有市民，其餘地域回傳空陣列（`18` §3 同款「依地域選池」
    /// 保底邏輯，只是保底是「沒有」而非退回另一張表——草原是空曠原野，不該無中生有冒出行人）。
    public static func slots(for region: RegionType) -> [Slot] {
        switch region {
        case .kingdom: return kingdomSlots
        case .meadowOrigin, .riverlands, .highlands, .coastalReach: return []
        }
    }

    /// NPC 層視差係數：與道具/地面同速（`layerFactor` 1.0），維持貼地錯覺。
    public static let layerFactor: Double = 1.0

    /// 計算某槽位在給定里程下的螢幕 x（沿用 `WorldScroll.wrappedX`，同 `PropScatter.screenX`）。
    public static func screenX(for slot: Slot, distance: Double) -> Double {
        WorldScroll.wrappedX(baseX: slot.baseX, distance: distance, layerFactor: layerFactor, span: span)
    }
}
