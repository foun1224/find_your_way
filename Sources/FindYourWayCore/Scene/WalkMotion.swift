import Foundation

/// 走路推進的純邏輯。
///
/// **ADR-009 語意變更**：`position` 不再是「螢幕水平座標」，而是**概念里程（distance）**——
/// 單調不減、無邊界、無折返。角色改為固定在畫面左側原地走路（walk-in-place），
/// 由世界（`WorldScroll`）依這個里程向左捲動來表現「前進」。
/// Phase 1 的「小人在畫面內左右來回 roam、碰邊界折返」語意已淘汰（見 `01_DECISIONS.md` ADR-009）。
///
/// **不 import SpriteKit / AppKit**，讓 `swift test` 能在 headless 環境下驗證。
public struct WalkMotion: Equatable {

    /// 目前累積里程（概念單位，非螢幕座標）。單調不減。
    public private(set) var position: Double

    /// 推進速率（里程單位/秒），恆為非負值。
    public let speed: Double

    /// - Parameters:
    ///   - position: 初始里程，會被夾在 `>= 0`（里程只增不減，不允許負值起點）。
    ///   - speed: 推進速率，必須為非負值。
    public init(position: Double = 0, speed: Double) {
        self.position = max(0, position)
        self.speed = max(0, speed)
    }

    /// 推進 `dt` 秒，恆向前（無邊界、無折返）。
    /// `dt <= 0` 或 `speed == 0` 時不改變位置（防負/零，與里程只增不減原則一致）。
    @discardableResult
    public mutating func step(dt: Double) -> WalkMotion {
        guard dt > 0, speed > 0 else { return self }
        position += speed * dt
        return self
    }
}
