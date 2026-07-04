import Foundation

/// 純邏輯：游標「靠近」主角時的感應判定（`docs/13_PSYCH_AUDIT.md` P2 / `02` §4 依附回應性、
/// ADR-006 嚴格零功利）。不 import AppKit/SpriteKit，供 `GameScene`（判定）與
/// `ClickThroughController`（游標移動事件來源）共用。
///
/// 這是「察覺你來了」的低門檻感應，語意上比 `CharacterHitTest`（點擊命中框）更寬鬆一圈——
/// 游標不需要精準落在角色本體上，只要「靠近」就會被溫柔地察覺到。判定本身重用
/// `CharacterHitTest.isPointOnCharacter` 的同一份矩形幾何，只是傳入更大的 `padding`
/// （見 `radiusPadding`），避免另開一套容易與命中框判斷兜不起來的邏輯。
public enum ProximityAwareness {

    /// 靠近感應半徑：比點擊命中框（`CharacterHitTest.hitPadding`）再外擴這麼多（點）。
    /// 刻意做成「一圈」而非「命中框本身放大」，語意上是感應圈、不是可點擊區。
    public static let radiusPadding: Double = 40

    /// 靠近感應總容差 = 點擊命中容差 + 感應圈外擴（供 `isNear` 使用，也方便測試直接引用）。
    public static var totalPadding: Double { CharacterHitTest.hitPadding + radiusPadding }

    /// 「察覺你來了」反應持續多久（秒）：比「偶爾看你」（`HeroRestSchedule`，2–3 秒）更短、
    /// 更輕——這是一次性的察覺，不是主動的休息。
    public static let acknowledgeDurationSeconds: TimeInterval = 1.0

    /// 節流冷卻（秒）：游標持續停留在感應圈內時，避免反覆狂觸發（`02` §2「臨場 ≠ 打擾」）。
    /// 只有「離開感應圈、再次進入」才會重新觸發（`shouldAcknowledge` 的 `wasNear` 語意）。
    public static let cooldownSeconds: TimeInterval = 20

    /// 判定某點是否落在「靠近感應圈」內（比點擊命中框大一圈）。
    public static func isNear(
        point: CGPoint,
        characterScreenX: Double,
        characterScreenY: Double,
        characterSize: CGSize,
        sceneSize: CGSize
    ) -> Bool {
        CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize,
            padding: totalPadding
        )
    }

    /// 排程判斷：是否該觸發一次「察覺你來了」反應。
    ///
    /// 這是邊緣觸發（edge-triggered，`wasNear == false && isNear == true` 才算「剛靠近」）
    /// 加上冷卻節流的組合純函式：即使游標持續留在感應圈內也不會重複觸發（`wasNear` 由呼叫端
    /// 追蹤上一輪狀態）；離開感應圈重置後，只要冷卻時間已過就可以再次觸發。
    ///
    /// - Parameters:
    ///   - wasNear: 上一次評估時是否已在感應圈內。
    ///   - isNear: 這一次評估時是否在感應圈內。
    ///   - now: 目前時間（`TimeProvider.now` 的單位，Unix 秒或任意單調遞增秒數）。
    ///   - lastAcknowledgeTime: 上一次觸發的時間；從未觸發過可傳極小值（例如 `-.infinity`）。
    public static func shouldAcknowledge(
        wasNear: Bool,
        isNear: Bool,
        now: Double,
        lastAcknowledgeTime: Double
    ) -> Bool {
        guard isNear, !wasNear else { return false }
        return now - lastAcknowledgeTime >= cooldownSeconds
    }
}
