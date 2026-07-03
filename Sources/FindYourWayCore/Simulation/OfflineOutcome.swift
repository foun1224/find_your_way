import Foundation

/// 離線結算「結果」值型別，供 Scene 層決定回歸呈現（`08` §3.8）。
/// **心理學把關**：`wasCapped` 只是內部截斷旗標，禁止呈現成「損失/浪費」（紅線二）。
public struct OfflineOutcome: Equatable {
    /// 本次實際套用的離線秒數（已夾在 `[0, OfflineProgress.capSeconds]`）。
    public let elapsedSecondsApplied: Double

    /// 本次離線結算增加的里程。
    public let distanceGained: Double

    /// 本次離線期間新通過的地標（保序）。
    public let newLandmarks: [Landmark]

    /// 原始 elapsed 是否超過上限而被截斷（僅供內部/除錯判斷，不對使用者呈現成損失）。
    public let wasCapped: Bool

    public init(elapsedSecondsApplied: Double, distanceGained: Double, newLandmarks: [Landmark], wasCapped: Bool) {
        self.elapsedSecondsApplied = elapsedSecondsApplied
        self.distanceGained = distanceGained
        self.newLandmarks = newLandmarks
        self.wasCapped = wasCapped
    }
}
