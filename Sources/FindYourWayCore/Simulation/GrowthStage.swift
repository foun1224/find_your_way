import Foundation

/// 成長階段/章節：由 `distance` 純函式衍生（`09` §4.2），**不持久化**——
/// 避免衍生欄位與 `distance` 漂移不一致。單調不減：`distance` 只增 → `stage` 只增（紅線一）。
/// 不引入常駐等級數字（§4.3 E4）：對外只顯示章節名，供 progressive disclosure（hover/日誌）使用。
public enum GrowthStage {

    /// 章節門檻表（`09` §10.4 定案）：依起始里程遞增排序，單一真相來源。
    private static let chapters: [(distance: Double, name: String)] = [
        (0, "第一章 · 啟程"),
        (Companion.meetDistance, "第二章 · 有人同行"),
        (432_000, "第三章 · 遠方的雪")
    ]

    /// 依里程對應成長階段索引（0 起算）。純函式、確定性、單調不減。
    public static func stage(forDistance distance: Double) -> Int {
        var result = 0
        for (index, chapter) in chapters.enumerated() where distance >= chapter.distance {
            result = index
        }
        return result
    }

    /// 依里程對應章節名（留白意象命名，`09` §10.4）。
    public static func chapterName(forDistance distance: Double) -> String {
        chapters[stage(forDistance: distance)].name
    }

    /// 回傳 `(old, new]` 區間內「新進入」的章節名（確定性、只看里程軸，不擲骰，
    /// 同 `SimulationRules.events(crossedFrom:to:)` 範式）。供跨章節時在旅程日誌顯示一行章節轉場。
    ///
    /// **門檻 0（第一章 · 啟程）為起始狀態、不算「跨越」**：`distance > old` 的嚴格條件天然排除
    /// 「從 0 開始」觸發 0 門檻（`09` §4.1；避免啟動時 toast）。
    public static func chaptersCrossed(from old: Double, to new: Double) -> [String] {
        guard new > old else { return [] }
        return chapters
            .filter { $0.distance > old && $0.distance <= new }
            .map { $0.name }
    }
}
