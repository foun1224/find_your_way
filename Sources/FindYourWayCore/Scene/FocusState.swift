import Foundation

/// 純邏輯：Stage P4「尊重專注的分寸」（`docs/22_COMPANIONSHIP_DESIGN.md` §4 P4 施工細節）——
/// 判斷使用者是否正埋頭專注中，供 `GameScene` 收起會拉注意力的行為（純減法）。
///
/// 不 import AppKit/SpriteKit，**只吃「OS 閒置秒數」這一個數字**（呼叫端用
/// `CGEventSource.secondsSinceLastEventType` 量測，同 `PresenceSchedule`），完全不知道
/// 「閒置秒數」以外的任何事——不讀視窗/app/鍵盤內容、不量化勤勞，只有「還在動 / 停手了」
/// 這一個二元粗訊號（隱私鐵律）。
///
/// 比照 `PresenceSchedule` 風格：純函式 `advance` 吃「上一刻狀態 + 這次量到的閒置秒數 + 距上次
/// 評估過了多久」，回傳「下一刻狀態」，不牆鐘、不含計時器/隨機數，方便單元測試逐步餵入序列驗證。
public enum FocusState {

    /// 「持續活動」的小門檻（秒）：閒置秒數需持續低於此值才算「仍在連續活動中」，用來累積
    /// 進入專注所需的連續活動時長。故意設短——比 `focusBreakSeconds` 更敏感——因為這是「進入」
    /// 門檻，要求真的持續盯著做才算數，稍有停頓（如切換視窗但仍在忙）就重新累積，避免斷斷續續
    /// 也被誤判為專注。
    public static let activeIdleCeilingSeconds: Double = 15

    /// 連續活動需累積超過此秒數才判定「進入專注/心流中」（`22` §4 P4：建議 240~300 秒）。
    /// 設得夠長，確保只有真的埋頭一段時間才收起行為，不會因為短暫連續打字幾十秒就誤判。
    public static let focusThresholdSeconds: Double = 270

    /// 閒置秒數一旦達到此值 → 判定「停手了」、立即退出專注（`22` §4 P4：建議 25~30 秒）。
    /// 刻意短於 P1c 陪你歇的 180 秒門檻（`PresenceSchedule.restIdleThresholdSeconds`）：
    /// 「退出專注、世界恢復生氣」該比「旅人坐下歇著」發生得更早——你只是停手喝口水/切個視窗，
    /// 世界就該先輕輕活過來；若閒置持續下去，180 秒後才輪到陪你歇接手（三態分層，`22` §4 P4）。
    public static let focusBreakSeconds: Double = 28

    /// 追蹤狀態：目前是否已判定「專注中」，以及正在累積中的連續活動時長。
    /// 值型別、無牆鐘依賴，方便測試建構任意起始狀態。
    public struct State: Equatable {
        public var isFocused: Bool
        public var continuousActiveSeconds: Double

        public init(isFocused: Bool = false, continuousActiveSeconds: Double = 0) {
            self.isFocused = isFocused
            self.continuousActiveSeconds = continuousActiveSeconds
        }
    }

    /// 依這次輪詢量到的閒置秒數、距上次評估過了多久（`dt`，由呼叫端用真實時鐘差算出，本函式
    /// 本身不碰牆鐘），推進 `state` 到下一刻。純函式：同一份輸入序列必定產生同一份輸出序列。
    ///
    /// - 已在專注中：只有「明顯停手」（`idleSeconds >= focusBreakSeconds`）才退出，退出時
    ///   累積歸零，重新開始算下一次進入專注。（`22` §4 P4「退場」邏輯。）
    /// - 尚未進入專注：閒置秒數持續低於 `activeIdleCeilingSeconds` 才累積連續活動時長；
    ///   一旦某次輪詢閒置超過此小門檻（但還沒到 `focusBreakSeconds`），視為活動不夠連續，
    ///   累積歸零重算——避免斷斷續續的活動也被誤判為專注。累積達到 `focusThresholdSeconds`
    ///   → 判定進入專注。
    public static func advance(_ state: State, idleSeconds: Double, dt: Double) -> State {
        var next = state

        if next.isFocused {
            if idleSeconds >= focusBreakSeconds {
                next.isFocused = false
                next.continuousActiveSeconds = 0
            }
            return next
        }

        guard idleSeconds < activeIdleCeilingSeconds else {
            next.continuousActiveSeconds = 0
            return next
        }

        next.continuousActiveSeconds += max(dt, 0)
        if next.continuousActiveSeconds >= focusThresholdSeconds {
            next.isFocused = true
        }
        return next
    }
}
