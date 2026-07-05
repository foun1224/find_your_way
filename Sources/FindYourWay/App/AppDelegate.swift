import AppKit
import CoreGraphics
import SpriteKit
import FindYourWayCore

/// 組裝視窗與場景（薄殼，難測部分留在這裡；邏輯已抽進 FindYourWayCore）。
///
/// Phase 2 新增：啟動載檔 → `OfflineProgress.settle` 離線結算 → 掛場景；
/// 存檔節流 + 關鍵時機（terminate / sleep）存檔；閒置/螢幕休眠時 `isPaused` 停 render 省電（`08` §8）。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var petWindow: PetWindow?
    private var gameScene: GameScene?
    private var statusItemController: StatusItemController?
    private var preferencesWindowController: PreferencesWindowController?
    /// Phase 4d 點角色微互動（`12` §5 / `04` §2.5 策略 B）：動態點擊穿透 + 手型 signifier。
    private var clickThroughController: ClickThroughController?

    private let timeProvider: TimeProvider = SystemTimeProvider()
    private let saveStore = SaveStore(paths: SavePaths())
    private let preferencesStore = PreferencesStore()

    private var lastSaveTime: Double = 0

    /// `08` §7 P7 provisional：存檔節流每 ~2 分鐘 + 關鍵時機（離線結算後 / terminate / sleep）。
    private let saveThrottleInterval: Double = 120

    /// P1 在場與歸來（`docs/22_COMPANIONSHIP_DESIGN.md` §4 Stage P1）：輪詢 OS 閒置秒數的計時器。
    /// **只讀「閒置了多少秒」這個系統層級的數字，無任何內容**（`CGEventSource`，隱私鐵律）。
    private var idlePollTimer: Timer?

    /// 輪詢間隔（秒）：陪你歇門檻是 180 秒、歸來門檻是 60 秒，這裡用遠小於兩者的間隔取樣，
    /// 讓兩個判斷的邊緣觸發（`PresenceSchedule`）夠即時，同時不至於太密集浪費資源。
    private static let idlePollInterval: TimeInterval = 5.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let size = PetWindowConfig.defaultSize
        // ADR-011：有記憶位置（且仍落在某個螢幕內）就開在該處，否則走既有右下角預設。
        let frame = initialFrame(defaultVisibleFrame: visibleFrame, windowSize: size)

        // 啟動載檔 → 離線結算（ADR-005）。無存檔則以全新狀態起步，`lastActiveTimestamp` 設為現在，
        // 避免第一次啟動被誤判為「離開了 1970 年至今」的離線時間。
        let loadedState = saveStore.load()
        let baseState = loadedState ?? GameState(lastActiveTimestamp: timeProvider.now)
        let (settledState, outcome) = OfflineProgress.settle(baseState, now: timeProvider.now, rules: .default)

        let scene = GameScene(
            size: size,
            initialState: settledState,
            initialOutcome: outcome,
            timeProvider: timeProvider
        )
        scene.onStateChanged = { [weak self] state in
            self?.handleStateChanged(state)
        }
        gameScene = scene

        let window = PetWindow(contentRect: frame)
        window.presentScene(scene)
        window.showWithoutActivating()
        // ADR-011（2026-07-04 更新）：整窗放開時位移<門檻＝短按——短按分流靠
        // `characterHitTest`（命中角色才觸發暖心回應，背景短按無作用）；超過門檻＝拖曳
        // （任一處皆可）→ 存記憶位置。
        window.onCharacterClicked = { [weak self] in
            self?.gameScene?.triggerWarmResponseFromConfirmedClick()
        }
        window.onWindowDragEnded = { [weak self] origin in
            self?.preferencesStore.setWindowOrigin(origin)
        }
        window.characterHitTest = { [weak self] pointInWindow in
            self?.gameScene?.isPointOnCharacter(pointInWindow) ?? false
        }
        petWindow = window

        // 離線結算後立即存檔一次（`08` §3.6 存檔時機）。
        saveStore.save(settledState)
        lastSaveTime = timeProvider.now

        let statusItem = StatusItemController(
            onToggleVisibility: { [weak self] in self?.toggleVisibility() },
            onOpenPreferences: { [weak self] in self?.openPreferences() },
            onQuit: { NSApp.terminate(nil) }
        )
        statusItem.gameStateProvider = { [weak self] in
            self?.gameScene?.gameState ?? GameState()
        }
        statusItem.install()
        statusItemController = statusItem

        let clickThrough = ClickThroughController(window: window, sceneProvider: { [weak self] in self?.gameScene })
        clickThrough.start()
        clickThroughController = clickThrough

        applyMotionPreference()
        setUpPowerObservers()
        setUpScreenParameterObserver()
        setUpMotionPreferenceObservers()
        setUpIdlePolling()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let state = gameScene?.gameState {
            saveStore.save(state)
        }
    }

    // MARK: - 存檔節流（`08` §3.6：tick 每次更新記憶體，寫盤節流）

    private func handleStateChanged(_ state: GameState) {
        let now = timeProvider.now
        guard now - lastSaveTime >= saveThrottleInterval else { return }
        saveStore.save(state)
        lastSaveTime = now
    }

    // MARK: - 省電：只在「確定看不到」時暫停（`08` §8.2b）
    //
    // 桌寵本質是「陪在身旁、可被看著」——**看 ≠ 輸入**。舊版以鍵鼠閒置（`CGEventSource`）判定
    // 靜止並凍結畫面，會把「使用者只是在看桌寵」誤判成離開而凍結（使用者回報「後面都不動了」）。
    // 修正：移除鍵鼠閒置暫停；只在系統睡眠 / 螢幕睡眠 / 被隱藏（確定看不到）時暫停省電。

    private func setUpPowerObservers() {
        let center = NSWorkspace.shared.notificationCenter

        // 系統睡眠 / 喚醒（既有，不動）。
        center.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // 螢幕睡眠 / 喚醒（`08` §8.2b 新增）：螢幕關了＝確定看不到 → 暫停省電。
        center.addObserver(
            self,
            selector: #selector(handleScreensDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleScreensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func handleWillSleep() {
        gameScene?.isPaused = true
        if let state = gameScene?.gameState {
            saveStore.save(state)
        }
    }

    @objc private func handleDidWake() {
        // P1a 歸來的溫暖（訊號 a：螢幕喚醒/解鎖）：在 `resumeWithCatchUp` **之前**呼叫，
        // 這樣若旅人恰好在陪你歇姿態中睡眠，還能走「恢復本身即歡迎」那個更自然的分支
        // （見 `GameScene.notifyScreenWake` 說明）。
        gameScene?.notifyScreenWake()
        // 睡眠喚醒走與離線啟動相同的 capped 補算（`08` §3.5，避免無上限尖峰補算）。
        gameScene?.resumeWithCatchUp()
    }

    @objc private func handleScreensDidSleep() {
        gameScene?.isPaused = true
        if let state = gameScene?.gameState {
            saveStore.save(state)
        }
    }

    @objc private func handleScreensDidWake() {
        // P1a：理由同 `handleDidWake`（螢幕睡眠/喚醒也是「使用者離開又回來」的訊號 a）。
        gameScene?.notifyScreenWake()
        gameScene?.resumeWithCatchUp()
    }

    // MARK: - 選單列動作

    private func toggleVisibility() {
        guard let window = petWindow else { return }
        if window.isVisible {
            // 隱藏＝確定看不到 → 暫停省電（`08` §8.2b）。
            window.orderOut(nil)
            gameScene?.isPaused = true
        } else {
            window.showWithoutActivating()
            // 重新可見：走 capped 補算恢復（與睡眠喚醒同路徑），而非單純 isPaused=false。
            gameScene?.resumeWithCatchUp()
        }
    }

    private func openPreferences() {
        let controller = preferencesWindowController ?? PreferencesWindowController()
        preferencesWindowController = controller
        controller.show()
    }

    // MARK: - 多螢幕穩定（`10` §7 / ADR-011）：螢幕參數變更（接拔/解析度）時重新錨定。

    /// 啟動時的初始 frame：有記憶位置（ADR-011）且仍落在目前任一螢幕內就用它（夾在該螢幕
    /// 可視範圍內，防止記憶位置在螢幕解析度變動後跑到畫面外）；否則走既有右下角預設。
    private func initialFrame(defaultVisibleFrame: CGRect, windowSize: CGSize) -> CGRect {
        guard let savedOrigin = preferencesStore.load().windowOrigin else {
            return PetWindowConfig.bottomRightFrame(visibleFrame: defaultVisibleFrame, windowSize: windowSize)
        }

        let visibleFrames = NSScreen.screens.map { $0.visibleFrame }
        guard let owningFrame = WindowPlacement.owningVisibleFrame(
            for: savedOrigin,
            windowSize: windowSize,
            visibleFrames: visibleFrames
        ) else {
            // 記憶位置已不在任何螢幕內（例如當初的外接螢幕已拔除）→ 回退合理落點。
            return PetWindowConfig.bottomRightFrame(visibleFrame: defaultVisibleFrame, windowSize: windowSize)
        }

        let clamped = WindowPlacement.clampedOrigin(savedOrigin, windowSize: windowSize, visibleFrame: owningFrame)
        return CGRect(origin: clamped, size: windowSize)
    }

    private func setUpScreenParameterObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// 螢幕變更時：目前位置若仍落在某個螢幕內，只夾在該螢幕可視範圍內（保留使用者拖曳的落點，
    /// 不無條件跳回右下角）；若已經懸空（該螢幕消失），才回退到有效螢幕右下角預設（`10` §7）。
    @objc private func handleScreenParametersChanged() {
        guard let window = petWindow else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = PetWindowConfig.defaultSize

        let visibleFrames = NSScreen.screens.map { $0.visibleFrame }
        let currentOrigin = window.frame.origin

        let frame: CGRect
        if let owningFrame = WindowPlacement.owningVisibleFrame(
            for: currentOrigin,
            windowSize: size,
            visibleFrames: visibleFrames
        ) {
            let clamped = WindowPlacement.clampedOrigin(currentOrigin, windowSize: size, visibleFrame: owningFrame)
            frame = CGRect(origin: clamped, size: size)
        } else {
            frame = PetWindowConfig.bottomRightFrame(visibleFrame: visibleFrame, windowSize: size)
        }
        window.setFrame(frame, display: true)
    }

    // MARK: - Reduce motion 消費點（`10` §4.3）：套用 effective 旗標到 render 層檢查點。

    private func setUpMotionPreferenceObservers() {
        // 使用者在偏好視窗切換、或在系統設定改「降低動態」，兩者都應即時反映（`10` §4.2）。
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyMotionPreference),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applyMotionPreference),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    @objc private func applyMotionPreference() {
        let systemPref = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let userOverride = preferencesStore.load().reduceMotionOverride
        let reduceMotion = MotionSettings.effectiveReduceMotion(userOverride: userOverride, systemPref: systemPref)
        gameScene?.motionEnabled = !reduceMotion
    }

    // MARK: - P1 在場與歸來（`docs/22_COMPANIONSHIP_DESIGN.md` §4 Stage P1）：
    // 輪詢 OS 閒置秒數，驅動 P1a 歸來的溫暖 + P1c 陪你歇（純判斷邏輯在
    // `PresenceSchedule`/`GameScene.notifyIdleSeconds`，這裡只是「量測」的薄殼）。
    //
    // **隱私鐵律**：只用 `CGEventSource.secondsSinceLastEventType` 讀「距上次任何輸入事件
    // 過了幾秒」這一個系統層級的數字——不讀視窗標題、不讀 app 名稱、不讀鍵盤內容、
    // 不知道使用者在做什麼，只知道「有沒有在動」。不引入任何 Accessibility/螢幕內容權限。

    private func setUpIdlePolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.idlePollInterval, repeats: true) { [weak self] _ in
            self?.pollIdleSeconds()
        }
        timer.tolerance = Self.idlePollInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        idlePollTimer = timer
        pollIdleSeconds() // 啟動時先量一次，建立 `lastIdleSeconds` 基準，避免第一次輪詢誤判邊緣觸發。
    }

    private func pollIdleSeconds() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        gameScene?.notifyIdleSeconds(idleSeconds)
    }
}
