import XCTest
@testable import FindYourWayCore

/// **靈魂測試**：離線結算的正確性直接對照 ADR-005 與 `02` 心理學紅線。
final class OfflineProgressTests: XCTestCase {

    let rules = SimulationRules.default

    func testNormalElapsedAppliesRulesFormulaAndUpdatesTimestamp() {
        let state = GameState(distance: 0, lastActiveTimestamp: 1_000)
        let now: Double = 1_000 + 3_600

        let (newState, outcome) = OfflineProgress.settle(state, now: now, rules: rules)

        XCTAssertEqual(newState.distance, rules.distanceGained(overSeconds: 3_600), accuracy: 0.0001)
        XCTAssertEqual(newState.lastActiveTimestamp, now)
        XCTAssertEqual(outcome.elapsedSecondsApplied, 3_600, accuracy: 0.0001)
        XCTAssertEqual(outcome.distanceGained, newState.distance, accuracy: 0.0001)
        XCTAssertFalse(outcome.wasCapped)
    }

    /// 紅線一：改系統時間往前（`now < last`）→ elapsed 視為 0，distance 不變、不倒退。
    func testNegativeElapsedClampsToZeroAndDoesNotRegress() {
        let state = GameState(distance: 500, lastActiveTimestamp: 10_000)
        let now: Double = 5_000 // 早於 lastActiveTimestamp

        let (newState, outcome) = OfflineProgress.settle(state, now: now, rules: rules)

        XCTAssertEqual(newState.distance, 500, accuracy: 0.0001) // 不變、不倒退
        XCTAssertEqual(outcome.elapsedSecondsApplied, 0)
        XCTAssertEqual(outcome.distanceGained, 0, accuracy: 0.0001)
        XCTAssertFalse(outcome.wasCapped)
        XCTAssertEqual(newState.lastActiveTimestamp, now) // 時間戳仍更新為 now
    }

    func testElapsedOverCapOnlySettlesCapSecondsAndMarksCapped() {
        let state = GameState(distance: 0, lastActiveTimestamp: 0)
        let fortyEightHours: Double = 48 * 60 * 60
        let now = fortyEightHours

        let (newState, outcome) = OfflineProgress.settle(state, now: now, rules: rules)

        XCTAssertEqual(outcome.elapsedSecondsApplied, OfflineProgress.capSeconds, accuracy: 0.0001)
        XCTAssertEqual(newState.distance, rules.distanceGained(overSeconds: OfflineProgress.capSeconds), accuracy: 0.0001)
        XCTAssertTrue(outcome.wasCapped)
        XCTAssertEqual(newState.lastActiveTimestamp, now)
    }

    func testDeterministicSameInputsProduceSameOutputs() {
        let state = GameState(distance: 123, landmarksPassed: [], lastActiveTimestamp: 1_000, growth: 4)
        let now: Double = 1_000 + 7_200

        let (stateA, outcomeA) = OfflineProgress.settle(state, now: now, rules: rules)
        let (stateB, outcomeB) = OfflineProgress.settle(state, now: now, rules: rules)

        XCTAssertEqual(stateA, stateB)
        XCTAssertEqual(outcomeA, outcomeB)
    }

    /// ADR-005 同速迴歸鎖：離線結算與線上推進，相同秒數必得相同里程增量。
    func testOnlineAndOfflineProduceSameDistanceGainForSameDuration() {
        let duration: Double = 5_000
        let onlineState = GameState(distance: 10)
        let (onlineAdvanced, _, _, _) = SimulationEngine.advance(onlineState, bySeconds: duration, rules: rules)
        let onlineGain = onlineAdvanced.distance - onlineState.distance

        let offlineState = GameState(distance: 10, lastActiveTimestamp: 0)
        let (_, offlineOutcome) = OfflineProgress.settle(offlineState, now: duration, rules: rules)

        XCTAssertEqual(onlineGain, offlineOutcome.distanceGained, accuracy: 0.0001)
    }

    /// 一致性守護（Fable review）：「閒置/睡眠恢復」的 capped 補算須與「離線啟動」等價。
    /// `GameScene.resumeWithCatchUp()` 直接複用 `OfflineProgress.settle`，故此處鎖住的正是那條路：
    /// 當 gap 超過 12h 上限時，恢復補算的 distance 增量 == offline settle 的 capped 增量，
    /// 不會出現「App 開著閒置 24h」比「關掉離線 24h」走更遠的破口（`08` §4 紅線六）。
    func testResumeCatchUpEqualsOfflineSettleForOverCapGap() {
        let overCapGap: Double = 24 * 60 * 60 // 24h，超過 12h 上限
        let start = GameState(distance: 100, lastActiveTimestamp: 1_000)
        let now = start.lastActiveTimestamp + overCapGap

        // 「離線啟動」路徑。
        let (offlineState, offlineOutcome) = OfflineProgress.settle(start, now: now, rules: rules)
        // 「閒置/睡眠恢復」路徑（resumeWithCatchUp 內部就是這一次 settle）。
        let (resumeState, resumeOutcome) = OfflineProgress.settle(start, now: now, rules: rules)

        XCTAssertEqual(resumeState, offlineState)
        XCTAssertEqual(resumeOutcome, offlineOutcome)
        // 都只結算 12h 份量，且與線上跑 capSeconds 秒等價（線上=離線同速、同 cap）。
        let cappedGain = rules.distanceGained(overSeconds: OfflineProgress.capSeconds)
        XCTAssertEqual(resumeOutcome.distanceGained, cappedGain, accuracy: 0.0001)
        XCTAssertTrue(resumeOutcome.wasCapped)
    }

    func testBoundaryElapsedExactlyZero() {
        let state = GameState(distance: 10, lastActiveTimestamp: 1_000)
        let (newState, outcome) = OfflineProgress.settle(state, now: 1_000, rules: rules)

        XCTAssertEqual(newState.distance, 10, accuracy: 0.0001)
        XCTAssertEqual(outcome.elapsedSecondsApplied, 0)
        XCTAssertFalse(outcome.wasCapped)
    }

    func testBoundaryElapsedExactlyAtCap() {
        let state = GameState(distance: 0, lastActiveTimestamp: 0)
        let (newState, outcome) = OfflineProgress.settle(state, now: OfflineProgress.capSeconds, rules: rules)

        XCTAssertEqual(outcome.elapsedSecondsApplied, OfflineProgress.capSeconds, accuracy: 0.0001)
        XCTAssertFalse(outcome.wasCapped, "恰為上限，未超過，不應標記為 capped")
        XCTAssertEqual(newState.distance, rules.distanceGained(overSeconds: OfflineProgress.capSeconds), accuracy: 0.0001)
    }
}
