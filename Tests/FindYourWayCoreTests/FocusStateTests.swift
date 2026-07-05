import XCTest
@testable import FindYourWayCore

final class FocusStateTests: XCTestCase {

    // MARK: - 進入專注：需連續活動累積超過門檻

    func testStaysUnfocusedBeforeThresholdReached() {
        var state = FocusState.State()
        // 分成多次小步推進，累積時間剛好停在門檻之前一秒。
        let step: Double = 5
        var elapsed: Double = 0
        while elapsed + step < FocusState.focusThresholdSeconds {
            state = FocusState.advance(state, idleSeconds: 1, dt: step)
            elapsed += step
        }
        XCTAssertFalse(state.isFocused)
    }

    func testEntersFocusOnceThresholdReached() {
        var state = FocusState.State()
        state = FocusState.advance(state, idleSeconds: 1, dt: FocusState.focusThresholdSeconds)
        XCTAssertTrue(state.isFocused)
    }

    func testEntersFocusAcrossMultiplePolls() {
        var state = FocusState.State()
        let pollInterval: Double = 5
        var polls = 0
        while !state.isFocused {
            state = FocusState.advance(state, idleSeconds: 1, dt: pollInterval)
            polls += 1
            XCTAssertLessThan(polls, 10_000, "should converge; guard against infinite loop on a logic bug")
        }
        // 累積時間應落在門檻附近（不會提早，也不會遠遠超過一個 poll 間隔才觸發）。
        XCTAssertGreaterThanOrEqual(Double(polls) * pollInterval, FocusState.focusThresholdSeconds)
        XCTAssertLessThan(Double(polls) * pollInterval, FocusState.focusThresholdSeconds + pollInterval)
    }

    // MARK: - 不牆鐘：只吃 idleSeconds + dt，同輸入序列必得同輸出

    func testAdvanceIsPureAndDeterministic() {
        let start = FocusState.State(isFocused: false, continuousActiveSeconds: 100)
        let a = FocusState.advance(start, idleSeconds: 2, dt: 10)
        let b = FocusState.advance(start, idleSeconds: 2, dt: 10)
        XCTAssertEqual(a, b)
    }

    // MARK: - 累積中出現「不算短閒置但未到退出門檻」的停頓 → 打斷累積、重新算

    func testMidPauseBelowBreakButAboveCeilingResetsAccumulation() {
        var state = FocusState.State()
        state = FocusState.advance(state, idleSeconds: 1, dt: FocusState.focusThresholdSeconds - 5)
        XCTAssertFalse(state.isFocused)
        XCTAssertGreaterThan(state.continuousActiveSeconds, 0)

        // 閒置介於 activeIdleCeilingSeconds 與 focusBreakSeconds 之間：不算「還在動」的連續累積，
        // 但也還沒到「明顯停手」退出門檻——此時尚未進入專注，故直接歸零累積重算。
        let midway = (FocusState.activeIdleCeilingSeconds + FocusState.focusBreakSeconds) / 2
        state = FocusState.advance(state, idleSeconds: midway, dt: 5)
        XCTAssertEqual(state.continuousActiveSeconds, 0)
        XCTAssertFalse(state.isFocused)
    }

    // MARK: - 退出專注：短閒置（focusBreakSeconds）立即退出，不需等到累積歸零之外的任何條件

    func testExitsFocusOnShortIdleBreak() {
        var state = FocusState.State(isFocused: true, continuousActiveSeconds: FocusState.focusThresholdSeconds)
        state = FocusState.advance(state, idleSeconds: FocusState.focusBreakSeconds, dt: 5)
        XCTAssertFalse(state.isFocused)
        XCTAssertEqual(state.continuousActiveSeconds, 0)
    }

    func testStaysFocusedBelowBreakThreshold() {
        var state = FocusState.State(isFocused: true, continuousActiveSeconds: FocusState.focusThresholdSeconds)
        state = FocusState.advance(state, idleSeconds: FocusState.focusBreakSeconds - 1, dt: 5)
        XCTAssertTrue(state.isFocused)
    }

    /// 已在專注中時，短暫的中等閒置（高於 `activeIdleCeilingSeconds` 但低於 `focusBreakSeconds`）
    /// 不該把人踢出專注——只有「明顯停手」（達到 `focusBreakSeconds`）才退出，這是刻意的
    /// hysteresis：專注一旦建立，偶爾切一下視窗查資料的小停頓不該立刻打斷。
    func testStayingFocusedIgnoresMidRangeIdleBelowBreakThreshold() {
        var state = FocusState.State(isFocused: true, continuousActiveSeconds: 0)
        let midway = (FocusState.activeIdleCeilingSeconds + FocusState.focusBreakSeconds) / 2
        state = FocusState.advance(state, idleSeconds: midway, dt: 5)
        XCTAssertTrue(state.isFocused)
    }

    func testExitsFocusWellAboveBreakThreshold() {
        var state = FocusState.State(isFocused: true, continuousActiveSeconds: 0)
        state = FocusState.advance(state, idleSeconds: FocusState.focusBreakSeconds * 10, dt: 5)
        XCTAssertFalse(state.isFocused)
    }

    // MARK: - 與 P1c 陪你歇門檻分層：focusBreakSeconds 遠小於 PresenceSchedule.restIdleThresholdSeconds

    func testFocusBreakThresholdIsMuchShorterThanAwayRestThreshold() {
        XCTAssertLessThan(FocusState.focusBreakSeconds, PresenceSchedule.restIdleThresholdSeconds)
    }

    // MARK: - 重新進入專注：退出後累積需從零開始重新累積到門檻

    func testReenteringFocusRequiresFullAccumulationAgain() {
        var state = FocusState.State(isFocused: true, continuousActiveSeconds: 0)
        // 明顯停手退出。
        state = FocusState.advance(state, idleSeconds: FocusState.focusBreakSeconds, dt: 5)
        XCTAssertFalse(state.isFocused)

        // 隨即恢復活動，但只累積了一小段時間，遠不到門檻——不該又立刻判定專注。
        state = FocusState.advance(state, idleSeconds: 1, dt: 10)
        XCTAssertFalse(state.isFocused)

        // 累積滿門檻才重新進入。
        state = FocusState.advance(state, idleSeconds: 1, dt: FocusState.focusThresholdSeconds)
        XCTAssertTrue(state.isFocused)
    }

    // MARK: - 初始狀態預設不專注

    func testDefaultStateIsNotFocused() {
        XCTAssertFalse(FocusState.State().isFocused)
    }
}
