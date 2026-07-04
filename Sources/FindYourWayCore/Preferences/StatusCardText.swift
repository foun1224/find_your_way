import Foundation

/// 狀態卡片文字組裝（純函式：`GameState → 顯示字串`，`10` §3.2 / §8.1）。
/// 三行封頂、克制 glanceable、無裸數字：
/// 1. 走了多遠 → 「已路過：<最近地標中文名>」（不顯示原始 `distance`）
/// 2. 第幾章 → `GrowthStage.chapterName`
/// 3. 是否已相遇 → 相遇後才顯示一行；未相遇則整行隱藏（非侵入、不製造「未達成」焦慮）
public enum StatusCardText {

    /// 尚未路過任何地標時的文字（`03` §3.3：世界的變化語言，非裸數字，非「未達成」焦慮）。
    public static let noLandmarksPassedText = "才剛啟程"

    public static let companionJoinedText = "旅伴同行中"

    /// 依 `GameState` 組出狀態卡片的行陣列（供 `NSMenuItem` 逐行掛入）。
    public static func lines(for state: GameState) -> [String] {
        var result: [String] = []
        result.append(distanceLine(for: state))
        result.append(GrowthStage.chapterName(forDistance: state.distance))
        if state.companionJoined {
            result.append(companionJoinedText)
        }
        return result
    }

    private static func distanceLine(for state: GameState) -> String {
        guard let lastLandmarkID = state.landmarksPassed.last,
              let landmark = Landmark.all.first(where: { $0.id == lastLandmarkID }) else {
            return noLandmarksPassedText
        }
        return "已路過：\(landmark.name)"
    }
}
