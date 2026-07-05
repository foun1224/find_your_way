import Foundation

/// 純邏輯：Stage P1「在場與歸來」（`docs/22_COMPANIONSHIP_DESIGN.md` §4 Stage P1）的
/// 判斷——**P1a 歸來的溫暖**、**P1c 陪你歇**。不 import AppKit/SpriteKit，只吃「OS 閒置秒數」
/// 這一種無內容的良性訊號（呼叫端用 `CGEventSource.secondsSinceLastEventType` 量測），
/// 供 `GameScene` 消費，也方便獨立單元測試（隱私鐵律：本檔案完全不知道「閒置秒數」以外的任何事）。
public enum PresenceSchedule {

    /// 閒置秒數 ≥ 此門檻 → 判定「使用者真的離開了」，觸發 P1c 陪你歇（旅人坐下休息）。
    ///
    /// 刻意設長（`22` §4 P1c「避開歷史 bug」）：之前用「短閒置就暫停世界」造成使用者盯著看時
    /// 畫面像壞了——180 秒足以區分「真的離開」與「只是在看你/滑鼠短暫停手」。
    public static let restIdleThresholdSeconds: Double = 180

    /// 閒置秒數曾經 ≥ 此門檻、之後活動恢復 → 也算一次「歸來」（P1a），即使還沒久到觸發
    /// P1c 陪你歇。刻意短於 `restIdleThresholdSeconds`：「離開一下又回來」（例如去倒水）
    /// 也值得一個輕迎接，不必等到旅人真的坐下休息那麼久才算數。
    public static let returnIdleThresholdSeconds: Double = 60

    /// 同一次「歸來」只播一次的冷卻（秒）：避免螢幕喚醒通知與閒置偵測兩條路徑幾乎同時觸發、
    /// 或閒置秒數在門檻附近抖動，反覆播出歡迎反應（`22` §3 低喚醒／不打斷）。
    public static let returnWelcomeCooldownSeconds: Double = 30

    /// 邊緣觸發判斷：依「上一次量到的閒置秒數」與「這一次量到的」判斷是否構成一次「歸來」。
    ///
    /// OS 閒置秒數只會隨時間單調上升，唯有真實輸入事件發生時才會被系統重置成接近 0——因此
    /// 「這一次量到的閒置秒數比上一次還小」本身就等於「剛剛發生了一次輸入」，不需要另外猜測
    /// 「多小才算剛活動」的門檻。「歸來」＝這次重置發生時，上一次量到的閒置已經 ≥
    /// `returnIdleThresholdSeconds`（也就是「離開得夠久，值得迎接」，避免每次隨手按一下鍵盤
    /// 都觸發）。純函式，不含任何計時器/隨機數，方便單元測試逐步餵入序列驗證。
    public static func isReturnTransition(previousIdleSeconds: Double, currentIdleSeconds: Double) -> Bool {
        previousIdleSeconds >= returnIdleThresholdSeconds && currentIdleSeconds < previousIdleSeconds
    }

    /// 是否該進入／維持 P1c 陪你歇（旅人坐下休息）：純粹依目前閒置秒數與門檻比較。
    /// 呼叫端以「邊緣觸發」方式使用（`false → true` 進入休息姿態、`true → false` 起身），
    /// 本函式本身不記憶狀態。
    public static func shouldRestTogether(idleSeconds: Double) -> Bool {
        idleSeconds >= restIdleThresholdSeconds
    }

    /// 冷卻判斷：距上次播放「歡迎回來」反應是否已經過了冷卻時間，可以再播一次。
    public static func canTriggerReturnWelcome(now: Double, lastTriggerTime: Double) -> Bool {
        now - lastTriggerTime >= returnWelcomeCooldownSeconds
    }
}
