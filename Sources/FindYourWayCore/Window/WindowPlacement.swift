import Foundation

/// 純函式：把一個視窗 origin 夾在指定螢幕 `visibleFrame` 內，以及判斷某個 origin
/// 是否仍落在任一已知螢幕範圍內（ADR-011：拖曳/記憶位置皆需守住「不跑到畫面外」）。
///
/// 不 import AppKit：只吃/吐 `CGPoint`/`CGRect`/`CGSize`，供 `PetWindow`（拖曳中即時夾取）與
/// `AppDelegate`（啟動載入記憶位置、螢幕變更時重新夾取/回退）共用同一份幾何判斷，可在
/// headless 測試環境下驗證，不需要真的建立 NSWindow/NSScreen。
public enum WindowPlacement {

    /// 把 `origin` 夾在 `visibleFrame` 內，讓 `CGRect(origin, windowSize)` 完整落在該螢幕可視範圍。
    /// 若 `windowSize` 比 `visibleFrame` 還大（極端情況），退而求其次貼齊左下角，避免產生無效區間。
    public static func clampedOrigin(
        _ origin: CGPoint,
        windowSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
        let x = min(max(origin.x, visibleFrame.minX), maxX)
        let y = min(max(origin.y, visibleFrame.minY), maxY)
        return CGPoint(x: x, y: y)
    }

    /// 判斷「以 `origin` 為左下角、`windowSize` 為尺寸」的視窗 frame，是否與 `visibleFrames`
    /// （目前所有螢幕的可視範圍）之中至少一個有重疊——用來決定記憶位置在螢幕變更後是否仍然有效，
    /// 或已經因外接螢幕拔除等原因「懸空」而需要回退到預設落點。
    public static func isOriginWithinAnyScreen(
        _ origin: CGPoint,
        windowSize: CGSize,
        visibleFrames: [CGRect]
    ) -> Bool {
        let frame = CGRect(origin: origin, size: windowSize)
        return visibleFrames.contains { $0.intersects(frame) }
    }

    /// 在 `visibleFrames` 中挑出「擁有」`origin` 的螢幕（與該點所在 frame 相交者的第一個），
    /// 找不到就回退第一個傳入的 frame（呼叫端已保證非空時使用）。
    public static func owningVisibleFrame(
        for origin: CGPoint,
        windowSize: CGSize,
        visibleFrames: [CGRect]
    ) -> CGRect? {
        let frame = CGRect(origin: origin, size: windowSize)
        return visibleFrames.first { $0.intersects(frame) }
    }
}
