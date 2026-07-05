import Foundation

/// 純函式：Stage P2「關係性時刻」（`docs/22_COMPANIONSHIP_DESIGN.md` §5b）。沿累積里程
/// （＝一起走過的時間，`gameState.distance` 為代理）**稀疏、確定性**地選一句 authored
/// 關係語氣文案（寫「我們」，與相遇卡寫景區隔）。**不依賴牆鐘**：同一 `(worldSeed, slotIndex)`
/// 永遠選到同一句，離線可重算。**不入 `GameState`、不持久化**（`22` §5b 紅線）：呼叫端
/// （`GameScene`）每次即時算，不記憶——與 `EncounterDeck` 同一套「無盡氛圍層」設計。
public enum RelationalMilestones {

    /// 關係槽間距（里程）：每 ~90000 里程一個「關係槽」（≈2h travel，比 `EncounterDeck.cardSpacing`
    /// 稀疏很多——關係性時刻是「很久才一次」的深水漣漪，不是常態的沿途風景，`22` §5b）。
    public static let relationalSpacing: Double = 90_000

    /// 固定編譯常數：與 `EncounterDeck.worldSeed` 不同值，避免兩套選句用同一顆種子產生
    /// 巧合的同步節奏（純裝飾細節，不影響各自的確定性本身）。"REL_Seed" ascii bytes。
    private static let worldSeed: UInt64 = 0x52_45_4C_5F_53_65_65_64

    /// `slotIndex = floor(distance / relationalSpacing)`（同 `EncounterDeck.slotIndex` 範式）。
    public static func slotIndex(atDistance distance: Double) -> Int {
        Int(floor(distance / relationalSpacing))
    }

    /// Authored 關係句（`22` §5b，一字照用；語氣：溫暖、留白、關係性、無數字、無成就、無圖鑑）。
    public static let lines: [String] = [
        "不知不覺，我們一起走了好長一段路。",
        "又一起走過了一個季節。",
        "一起看過的日落，已經數不清了。",
        "路還長，還好有你在。",
        "有些風景，是因為有人一起看著，才留得住。",
        "你在的時候，連沉默都覺得踏實。"
    ]

    /// 確定性選句：`hash(worldSeed, slotIndex) % lines.count`；若與**上一槽實際選中的句子**
    /// （非上一槽的原始 hash 基準值——只比對基準值在句子池很小時會漏放過連鎖調整後仍緊鄰重複
    /// 的情況，故沿著鏈從 slot 0 逐步解到 `slotIndex`，保證每一步都真的避開了上一步的實際輸出）
    /// 相同則取次順位（環狀嘗試整份清單）。`lines.count` 小、稀疏出現時這個保證比
    /// `EncounterDeck`（76 張大池、碰撞機率低到可忽略基準值差異）更需要嚴謹處理。
    public static func line(atSlot slotIndex: Int) -> String {
        lines[resolvedIndex(atSlot: slotIndex)]
    }

    /// 沿鏈逐步解出 `slotIndex` 實際選中的索引：時間/效能上為 `O(slotIndex)`，對本專案的
    /// 現實運行時間尺度（`relationalSpacing` ≈ 2h travel，數年運行也僅數萬槽）完全可忽略。
    private static func resolvedIndex(atSlot slotIndex: Int) -> Int {
        guard lines.count > 1 else { return baseIndex(atSlot: 0) }
        var currentIndex = baseIndex(atSlot: 0)
        guard slotIndex > 0 else { return currentIndex }
        for slot in 1...slotIndex {
            let base = baseIndex(atSlot: slot)
            currentIndex = base == currentIndex ? nextDifferentIndex(from: base, avoiding: currentIndex) : base
        }
        return currentIndex
    }

    private static func baseIndex(atSlot slotIndex: Int) -> Int {
        Int(mix(worldSeed: worldSeed, slotIndex: slotIndex) % UInt64(lines.count))
    }

    /// 從 `base` 開始環狀嘗試整份清單，取第一個不等於 `previous` 的索引。
    private static func nextDifferentIndex(from base: Int, avoiding previous: Int) -> Int {
        for offset in 0..<lines.count {
            let candidate = (base + offset) % lines.count
            if candidate != previous {
                return candidate
            }
        }
        // 理論不可達：`lines.count > 1` 保證至少有一句與上一槽不同。
        return base
    }

    /// 確定性整數混雜（splitmix64 風格，同 `EncounterDeck.mix`/`Weather.kind(forEpochIndex:)` 範式）。
    private static func mix(worldSeed: UInt64, slotIndex: Int) -> UInt64 {
        var x = worldSeed &+ UInt64(bitPattern: Int64(slotIndex)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 33
        x = x &* 0xff51afd7ed558ccd
        x ^= x >> 33
        x = x &* 0xc4ceb9fe1a85ec53
        x ^= x >> 33
        return x
    }
}
