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

    private let timeProvider: TimeProvider = SystemTimeProvider()
    private let saveStore = SaveStore(paths: SavePaths())
    private let preferencesStore = PreferencesStore()

    private var lastSaveTime: Double = 0

    /// `08` §7 P7 provisional：存檔節流每 ~2 分鐘 + 關鍵時機（離線結算後 / terminate / sleep）。
    private let saveThrottleInterval: Double = 120

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let size = PetWindowConfig.defaultSize
        let frame = PetWindowConfig.bottomRightFrame(visibleFrame: visibleFrame, windowSize: size)

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

        applyMotionPreference()
        setUpPowerObservers()
        setUpScreenParameterObserver()
        setUpMotionPreferenceObservers()
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

    // MARK: - 多螢幕穩定（`10` §7）：螢幕參數變更（接拔/解析度）時重新錨定到有效螢幕右下角。

    private func setUpScreenParameterObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleScreenParametersChanged() {
        guard let window = petWindow else { return }
        // 主螢幕消失時 fallback 到第一個可用螢幕，避免落到不存在的螢幕外（`10` §7）。
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = PetWindowConfig.bottomRightFrame(visibleFrame: visibleFrame, windowSize: PetWindowConfig.defaultSize)
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
}
