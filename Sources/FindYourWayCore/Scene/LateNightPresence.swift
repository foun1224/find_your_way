import Foundation

/// 純邏輯：Stage P2「與你同步的一天」深夜陪伴（`docs/22_COMPANIONSHIP_DESIGN.md` §5b）。
/// 只吃「真實時刻換算出的當日秒數」這一種良性訊號（`GameScene.localSecondsIntoDay`，
/// 與 `DayNightCycle` 同一份真實時鐘，本檔案完全不知道使用者在做什麼——隱私鐵律同
/// `PresenceSchedule`）。不 import AppKit/SpriteKit，方便獨立單元測試。
///
/// **鐵律**（`22` §6）：純在場陪伴，本檔案的文案/邏輯絕不含「去睡/該休息/健康」語氣——
/// 那是侵入，是提醒 app 的行為，不是陪伴。
public enum LateNightPresence {

    /// 深夜窗口起點：23:00（含）。
    private static let lateNightStart: Double = 23 * 3600
    /// 深夜窗口終點：次日 04:00（不含）。窗口跨午夜，見 `isLateNight` 的 wrap 判斷。
    private static let lateNightEnd: Double = 4 * 3600

    /// 破曉窗口：05:00（含）到 07:00（不含），不跨午夜。
    private static let dawnStart: Double = 5 * 3600
    private static let dawnEnd: Double = 7 * 3600

    /// 深夜陪伴冷卻（`22` §5b「稀疏，長冷卻，建議每次深夜時段內間隔 ≥ 30~45 分」）：
    /// 取中間值 35 分，確保一個深夜時段（23:00–04:00，共 5 小時）內最多播約 8~9 次上限，
    /// 實務上因使用者不會整夜連續在場而遠低於此——足夠「稀疏」。
    public static let lateNightCooldownSeconds: Double = 35 * 60

    /// 破曉句冷卻：刻意設得比一整個晚上還長（12h），確保同一個破曉窗口最多播一次（罕見）。
    public static let dawnCooldownSeconds: Double = 12 * 3600

    /// `secondsIntoDay`（`[0, 86400)`）是否落在深夜窗口內（23:00–24:00 或 0:00–04:00，跨午夜 wrap）。
    public static func isLateNight(secondsIntoDay: Double) -> Bool {
        secondsIntoDay >= lateNightStart || secondsIntoDay < lateNightEnd
    }

    /// `secondsIntoDay` 是否落在破曉窗口內（05:00–07:00，不跨午夜）。
    public static func isDawn(secondsIntoDay: Double) -> Bool {
        secondsIntoDay >= dawnStart && secondsIntoDay < dawnEnd
    }

    /// 冷卻判斷：距上次播放是否已經過了 `cooldown` 秒，可以再播一次
    /// （同 `PresenceSchedule.canTriggerReturnWelcome` 範式，泛化成可傳入不同冷卻長度）。
    public static func canTrigger(now: Double, lastTriggerTime: Double, cooldown: Double) -> Bool {
        now - lastTriggerTime >= cooldown
    }

    /// Authored 深夜陪伴句（`22` §5b，一字照用；語氣：純在場、絕不勸睡）。
    public static let lateNightLines: [String] = [
        "夜深了。你還在，我也還在。",
        "夜裡很安靜，我陪你走一段。",
        "燈還亮著。不急，我在。",
        "這麼晚了還在忙。我不吵你，就在這。"
    ]

    /// Authored 破曉句（`22` §5b，一字照用；罕見，僅破曉窗口出現）。
    public static let dawnLine: String = "天要亮了。這一夜，有你，不孤單。"

    /// 深夜句的確定性選句槽：用「現在落在第幾個冷卻週期」（`floor(now / lateNightCooldownSeconds)`）
    /// 當輸入，而非里程——深夜陪伴綁的是真實時刻軸，不是旅程軸。**不依賴額外狀態**：
    /// 同一冷卻週期內永遠選到同一句，跨週期依序混雜、避免緊鄰重複（同 `EncounterDeck` 範式）。
    public static func lateNightSlotIndex(atUnixSeconds now: Double) -> Int {
        Int(floor(now / lateNightCooldownSeconds))
    }

    /// 確定性選句：若與**上一槽實際選中的句子**（非上一槽的原始 hash 基準值，見
    /// `RelationalMilestones.resolvedIndex` 同一段說明——句子池很小時只比對基準值會漏放過
    /// 連鎖調整後仍緊鄰重複的情況）相同則取次順位（環狀嘗試整份清單）。
    public static func lateNightLine(atSlot slotIndex: Int) -> String {
        lateNightLines[resolvedIndex(atSlot: slotIndex)]
    }

    /// 沿鏈逐步解出 `slotIndex` 實際選中的索引，`O(slotIndex)`（同 `RelationalMilestones` 範式，
    /// 對現實運行時間尺度可忽略——`lateNightCooldownSeconds` ≈ 35 分，數年運行也僅數萬槽）。
    private static func resolvedIndex(atSlot slotIndex: Int) -> Int {
        guard lateNightLines.count > 1 else { return baseIndex(atSlot: 0) }
        var currentIndex = baseIndex(atSlot: 0)
        guard slotIndex > 0 else { return currentIndex }
        for slot in 1...slotIndex {
            let base = baseIndex(atSlot: slot)
            currentIndex = base == currentIndex ? nextDifferentIndex(from: base, avoiding: currentIndex) : base
        }
        return currentIndex
    }

    private static func baseIndex(atSlot slotIndex: Int) -> Int {
        Int(mix(worldSeed: worldSeed, slotIndex: slotIndex) % UInt64(lateNightLines.count))
    }

    /// 從 `base` 開始環狀嘗試整份清單，取第一個不等於 `previous` 的索引。
    private static func nextDifferentIndex(from base: Int, avoiding previous: Int) -> Int {
        for offset in 0..<lateNightLines.count {
            let candidate = (base + offset) % lateNightLines.count
            if candidate != previous {
                return candidate
            }
        }
        // 理論不可達：`lateNightLines.count > 1` 保證至少有一句與上一槽不同。
        return base
    }

    /// 固定編譯常數，與 `EncounterDeck.worldSeed`/`RelationalMilestones.worldSeed` 不同值。
    /// "NIGHT_Sd" ascii bytes。
    private static let worldSeed: UInt64 = 0x4E_49_47_48_54_5F_53_64

    /// 確定性整數混雜（splitmix64 風格，同 `EncounterDeck.mix` 範式）。
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
