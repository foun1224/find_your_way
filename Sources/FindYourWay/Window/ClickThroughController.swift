import AppKit
import FindYourWayCore

/// 動態點擊穿透（Phase 4d，`04_ARCHITECTURE.md` §2.5 策略 B / `12_PHASE4_SPEC.md` §5）：
/// 追蹤游標位置，游標在角色命中框內時短暫接管點擊（`ignoresMouseEvents = false` + 手型游標，
/// signifier），其餘時間整窗維持穿透（不擋操作、不搶焦點）。
///
/// **R3 實測（風險，`04`/`12`）**：`NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` 在
/// 本專案（ad-hoc 自用、非沙盒，ADR-008）下**不需要 Accessibility 權限**——啟動後立即生效，
/// 系統未彈出任何權限對話框，「輔助使用」清單也未出現本 App。Accessibility 權限的需求限於
/// 全域「鍵盤」事件監聽/合成事件（keylogging 等敏感操作），被動讀取滑鼠移動座標不在此列。
///
/// 之所以同時掛「全域」與「本視窗內」兩個 monitor：`ignoresMouseEvents == true` 時，
/// 視窗完全不吃事件，滑鼠移到視窗所在螢幕區域的事件會被視窗系統當成「底下那層」的事件，
/// 只有全域 monitor 收得到；一旦切成 `false`（游標在角色上），事件轉為正常投遞給本視窗，
/// 這時只有本地 monitor 收得到。兩者合起來才能在整個 hover 過程中持續追蹤，不漏拍。
final class ClickThroughController {

    private weak var window: PetWindow?
    private let sceneProvider: () -> GameScene?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// 目前是否處於「游標在角色上」狀態，避免每次滑鼠移動都重覆切換視窗旗標/游標（只在狀態變化時動作）。
    private var isHovering = false

    init(window: PetWindow, sceneProvider: @escaping () -> GameScene?) {
        self.window = window
        self.sceneProvider = sceneProvider
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.evaluateHover()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.evaluateHover()
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        if isHovering {
            isHovering = false
            NSCursor.pop()
        }
    }

    deinit {
        stop()
    }

    /// 查目前游標的螢幕位置，換算到視窗座標系（與 `GameScene`/`SKView` 座標系一致，
    /// 皆為左下原點、視窗填滿場景，無需再轉換），委派 `GameScene.isPointOnCharacter`
    /// （底層為可測的 `CharacterHitTest` 純函式）判定是否命中角色。
    private func evaluateHover() {
        guard let window, window.isVisible, let scene = sceneProvider() else {
            setHovering(false)
            return
        }

        let screenPoint = NSEvent.mouseLocation
        let pointInWindow = window.convertPoint(fromScreen: screenPoint)
        let hit = scene.isPointOnCharacter(pointInWindow)
        setHovering(hit)
    }

    private func setHovering(_ hit: Bool) {
        guard hit != isHovering else { return }
        isHovering = hit

        // 策略 B（`04` §2.5）：命中角色 → 吃點擊；否則整窗穿透，維持非侵入。
        window?.ignoresMouseEvents = !hit

        // signifier（ADR-006：不掛常駐按鈕，用「角色生命反應」+ 游標變化）：
        // push/pop 成對出現，避免永久覆蓋掉其他 App 原本的游標形狀。
        if hit {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }
}
