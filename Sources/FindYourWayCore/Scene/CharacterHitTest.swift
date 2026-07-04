import Foundation

/// 純邏輯：判定一個（視窗/場景座標系）點是否落在角色的命中框內（Phase 4d 微互動，
/// `12_PHASE4_SPEC.md` §5 / `04_ARCHITECTURE.md` §2.5 策略 B）。
///
/// 不 import AppKit/SpriteKit，供 `GameScene`（點擊觸發暖心回應）與執行檔層的
/// `ClickThroughController`（游標移動 → 動態切換 `ignoresMouseEvents`）共用同一份幾何判斷，
/// 避免兩處各自實作導致「滑鼠變手型的範圍」與「實際點得到的範圍」不一致。
///
/// 命中框以角色的 `anchorPoint = (0.5, 0)`（螢幕座標，腳邊為錨點）換算：
/// x 以 `characterScreenX` 置中、y 由 `characterScreenY`（腳邊）往上到腳邊+高度。
/// 依 ADR-006「命中區＝整個角色（Fitts's law）」，額外加一圈 `hitPadding` 容差，
/// 讓命中框略比精確 sprite 尺寸寬鬆，好點、不刁鑽。
public enum CharacterHitTest {

    /// 命中容差（點）：命中框四周各外擴這麼多，降低「差一點點點不到」的挫折感。
    public static let hitPadding: Double = 6

    /// - Parameters:
    ///   - point: 待測點，與 `characterScreenX`/`characterScreenY` 同一座標系（場景/視窗座標，左下原點）。
    ///   - characterScreenX: 角色錨點 x（螢幕水平置中座標）。
    ///   - characterScreenY: 角色錨點 y（腳邊，`anchorPoint.y = 0`）。
    ///   - characterSize: 角色目前顯示尺寸（寬高，點）。
    ///   - sceneSize: 場景/視窗尺寸，用於排除場景外的點（例如轉換座標時的浮點誤差落到邊界外）。
    ///   - padding: 命中框四周外擴的容差（點）。預設為 `hitPadding`（點擊命中用）；
    ///     `ProximityAwareness`（P2 靠近感應，`13_PSYCH_AUDIT.md`）會傳入更大的值，
    ///     重用同一份幾何判斷做「比點擊更寬鬆的靠近圈」，而非另開一套判定邏輯。
    public static func isPointOnCharacter(
        point: CGPoint,
        characterScreenX: Double,
        characterScreenY: Double,
        characterSize: CGSize,
        sceneSize: CGSize,
        padding: Double = hitPadding
    ) -> Bool {
        guard
            point.x >= 0, point.x <= Double(sceneSize.width),
            point.y >= 0, point.y <= Double(sceneSize.height)
        else {
            return false
        }

        let halfWidth = Double(characterSize.width) / 2.0 + padding
        let minX = characterScreenX - halfWidth
        let maxX = characterScreenX + halfWidth
        let minY = characterScreenY - padding
        let maxY = characterScreenY + Double(characterSize.height) + padding

        return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}
