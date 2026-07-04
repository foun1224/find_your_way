import Foundation

/// 離線結算「結果」值型別，供 Scene 層決定回歸呈現（`08` §3.8；`09` §2.4/§3）。
/// **心理學把關**：`wasCapped` 只是內部截斷旗標，禁止呈現成「損失/浪費」（紅線二）；
/// 未走到的里程與其事件不會消失，下次繼續走就會遇到。
public struct OfflineOutcome: Equatable {
    /// 本次實際套用的離線秒數（已夾在 `[0, OfflineProgress.capSeconds]`）。
    public let elapsedSecondsApplied: Double

    /// 本次離線結算增加的里程。
    public let distanceGained: Double

    /// 本次離線期間新通過的地標（保序）。
    public let newLandmarks: [Landmark]

    /// 本次離線期間新遇里程事件（含旅伴相遇，保序，`09` §2.4）。
    public let newEvents: [JourneyEvent]

    /// 本次離線期間新進入的章節名（保序，`09` §4.1 章節感）；供回歸時在旅程日誌顯示章節轉場。
    public let newChapters: [String]

    /// 本次離線結算是否恰好觸發旅伴相遇（供呈現 peak，`09` §3.4）。
    public let companionJustJoined: Bool

    /// 原始 elapsed 是否超過上限而被截斷（僅供內部/除錯判斷，不對使用者呈現成損失）。
    public let wasCapped: Bool

    public init(
        elapsedSecondsApplied: Double,
        distanceGained: Double,
        newLandmarks: [Landmark],
        newEvents: [JourneyEvent] = [],
        newChapters: [String] = [],
        companionJustJoined: Bool = false,
        wasCapped: Bool
    ) {
        self.elapsedSecondsApplied = elapsedSecondsApplied
        self.distanceGained = distanceGained
        self.newLandmarks = newLandmarks
        self.newEvents = newEvents
        self.newChapters = newChapters
        self.companionJustJoined = companionJustJoined
        self.wasCapped = wasCapped
    }
}
