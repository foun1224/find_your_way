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

    private let timeProvider: TimeProvider = SystemTimeProvider()
    private let saveStore = SaveStore(paths: SavePaths())

    private var idleCheckTimer: Timer?
    private var lastSaveTime: Double = 0

    /// `08` §7 P7 provisional：存檔節流每 ~2 分鐘 + 關鍵時機（離線結算後 / terminate / sleep）。
    private let saveThrottleInterval: Double = 120

    /// 省電（`08` §8.2）：使用者閒置超過此秒數視為「靜止」，暫停 render。
    private let idleThreshold: Double = 60

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
            onQuit: { NSApp.terminate(nil) }
        )
        statusItem.install()
        statusItemController = statusItem

        setUpPowerObservers()
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

    // MARK: - 省電：靜止即 isPaused（`08` §8.2，R1 顯示底噪偏高，故必做）

    private func setUpPowerObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // 低頻檢查系統閒置時間（距上次滑鼠/鍵盤事件多久），取代逐幀輪詢：
        // 閒置超過門檻 → 暫停 render（`scene.isPaused = true`）；有活動時恢復。
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkIdleAndUpdatePauseState()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        idleCheckTimer = timer
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

    private func checkIdleAndUpdatePauseState() {
        guard let scene = gameScene else { return }
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
        let shouldPause = idleSeconds >= idleThreshold

        if shouldPause {
            scene.isPaused = true
        } else if scene.isPaused {
            // 閒置→活動：解除暫停時走 capped 補算，而非單純 isPaused=false（避免大 dt 尖峰重複補算）。
            scene.resumeWithCatchUp()
        }
    }

    // MARK: - 選單列動作

    private func toggleVisibility() {
        guard let window = petWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.showWithoutActivating()
        }
    }
}
