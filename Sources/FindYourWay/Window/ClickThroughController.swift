import AppKit
import FindYourWayCore

/// 動態點擊穿透（Phase 4d，`04_ARCHITECTURE.md` §2.5 策略 B / `12_PHASE4_SPEC.md` §5；
/// **ADR-011 2026-07-04 更新「背景也可以拖曳」後改寫**）：
/// 追蹤游標位置，游標在**整個視窗 frame** 內時就接管點擊（`ignoresMouseEvents = false`），
/// 讓背景也能被抓來拖曳整個視窗；游標離開視窗才切回穿透（不擋視窗以外的桌面操作）。
///
/// 角色命中框（`CharacterHitTest`）仍然保留、獨立評估——現在只用來決定**手型游標 signifier**
/// （命中角色才變手型，暗示「這裡可以互動出暖心回應」；背景維持一般游標，暗示「這裡只能拖曳」），
/// 不再決定是否吃點擊。真正的角色 vs 背景短按分流，交給 `PetWindow.characterHitTest`
/// （放開時才判定，見該檔），這裡的手型只是視覺提示，兩處共用同一份 `CharacterHitTest` 幾何判斷。
///
/// **R3 實測（風險，`04`/`12`）**：`NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` 在
/// 本專案（ad-hoc 自用、非沙盒，ADR-008）下**不需要 Accessibility 權限**——啟動後立即生效，
/// 系統未彈出任何權限對話框，「輔助使用」清單也未出現本 App。Accessibility 權限的需求限於
/// 全域「鍵盤」事件監聽/合成事件（keylogging 等敏感操作），被動讀取滑鼠移動座標不在此列。
///
/// 之所以同時掛「全域」與「本視窗內」兩個 monitor：`ignoresMouseEvents == true` 時，
/// 視窗完全不吃事件，滑鼠移到視窗所在螢幕區域的事件會被視窗系統當成「底下那層」的事件，
/// 只有全域 monitor 收得到；一旦切成 `false`（游標進入視窗），事件轉為正常投遞給本視窗，
/// 這時只有本地 monitor 收得到。兩者合起來才能在整個 hover 過程中持續追蹤，不漏拍。
final class ClickThroughController {

    private weak var window: PetWindow?
    private let sceneProvider: () -> GameScene?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// 目前是否處於「游標在視窗 frame 內」狀態（控制 `ignoresMouseEvents`），
    /// 避免每次滑鼠移動都重覆切換視窗旗標（只在狀態變化時動作）。
    private var isInsideWindow = false
    /// 目前是否處於「游標在角色命中框內」狀態（只控制手型游標 signifier，見上方類別註解）。
    private var isOnCharacter = false

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
        if isOnCharacter {
            NSCursor.pop()
        }
        isInsideWindow = false
        isOnCharacter = false
    }

    deinit {
        stop()
    }

    /// 查目前游標的螢幕位置，換算到視窗座標系（與 `GameScene`/`SKView` 座標系一致，
    /// 皆為左下原點、視窗填滿場景，無需再轉換）。**ADR-011 更新**：是否吃點擊
    /// （`ignoresMouseEvents`）改由「游標是否在整個視窗 frame 內」決定，不再限於角色；
    /// 角色命中判定（`GameScene.isPointOnCharacter`，底層 `CharacterHitTest` 純函式）
    /// 只保留來驅動手型游標 signifier。
    private func evaluateHover() {
        guard let window, window.isVisible, let scene = sceneProvider() else {
            setInsideWindow(false)
            setOnCharacter(false)
            return
        }

        let screenPoint = NSEvent.mouseLocation
        setInsideWindow(window.frame.contains(screenPoint))

        let pointInWindow = window.convertPoint(fromScreen: screenPoint)
        let hit = scene.isPointOnCharacter(pointInWindow)
        setOnCharacter(hit)

        // 靠近感應（`13_PSYCH_AUDIT.md` P2）：比點擊命中框大一圈的溫和覺察，與「吃點擊」的
        // 命中判斷各自獨立評估——游標可以「靠近但還沒進命中框」就先被角色察覺到。
        let near = scene.isPointNearCharacter(pointInWindow)
        scene.notifyCursorNearState(near)
    }

    /// 整窗皆可拖曳（ADR-011 更新）：游標在視窗 frame 內就吃事件，離開才放回穿透。
    private func setInsideWindow(_ inside: Bool) {
        guard inside != isInsideWindow else { return }
        isInsideWindow = inside
        window?.ignoresMouseEvents = !inside
    }

    /// signifier（ADR-006：不掛常駐按鈕，用「角色生命反應」+ 游標變化）：
    /// push/pop 成對出現，避免永久覆蓋掉其他 App 原本的游標形狀。只影響游標外觀，
    /// 不影響是否吃點擊（見 `setInsideWindow`）。
    private func setOnCharacter(_ hit: Bool) {
        guard hit != isOnCharacter else { return }
        isOnCharacter = hit

        if hit {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }
}
