import Foundation

/// 全專案唯一取得「現在」的入口。`Date()` 只允許出現在 `SystemTimeProvider` 內部，
/// 其餘所有時間相關邏輯一律透過本協定注入，確保可測、確定性（`08` §3.4）。
public protocol TimeProvider {
    /// 現在時刻，Unix 秒（`Date().timeIntervalSince1970` 的單位）。
    var now: Double { get }
}

/// 真實系統時鐘。僅本型別允許呼叫 `Date()`。
public struct SystemTimeProvider: TimeProvider {
    public init() {}
    public var now: Double { Date().timeIntervalSince1970 }
}

/// 測試用：固定不變的時間點。
public struct FixedTimeProvider: TimeProvider {
    public var now: Double
    public init(now: Double) {
        self.now = now
    }
}

/// 測試用：可手動推進的時間點，模擬「經過一段時間」而不必真的等待。
public final class ManualTimeProvider: TimeProvider {
    public private(set) var now: Double

    public init(now: Double = 0) {
        self.now = now
    }

    /// 手動推進時間。
    public func advance(by seconds: Double) {
        now += seconds
    }

    /// 直接設定為某一時刻（例如模擬使用者調整系統時間）。
    public func set(now: Double) {
        self.now = now
    }
}
