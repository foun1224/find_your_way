import Foundation

/// 純函式：以「移動距離門檻」區分「短按點擊」與「拖曳移動視窗」（ADR-011）。
///
/// 沒有超過門檻＝點擊（維持 ADR-006 暖心回應）；超過門檻＝拖曳（該次不觸發暖心回應，改為
/// 移動整個視窗）。不 import AppKit，供 `PetWindow`（實際處理 `mouseDown`/`mouseDragged`/`mouseUp`）
/// 使用，邏輯本身可在 headless 測試環境下驗證。
public enum WindowDragGesture {

    /// 判定門檻（點）：放開時位移小於此值視為點擊，大於等於視為拖曳。
    /// 4pt 是「按住手還沒穩定移到別處」的常見容忍值，避免手震誤判成拖曳。
    public static let defaultThreshold: Double = 4.0

    /// 依起點/終點座標差，判斷是否已超過拖曳門檻。
    public static func exceedsThreshold(
        dx: Double,
        dy: Double,
        threshold: Double = defaultThreshold
    ) -> Bool {
        let distanceSquared = dx * dx + dy * dy
        return distanceSquared > threshold * threshold
    }
}
