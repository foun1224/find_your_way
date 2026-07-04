import XCTest
@testable import FindYourWayCore

/// T10：成長階段，純函式衍生（`09_PHASE3_SPEC.md` §5 T10 / §4.2，門檻定案 §10.4）。
final class GrowthStageTests: XCTestCase {

    func testStageZeroAtOrigin() {
        XCTAssertEqual(GrowthStage.stage(forDistance: 0), 0)
        XCTAssertEqual(GrowthStage.chapterName(forDistance: 0), "第一章 · 啟程")
    }

    func testStageJustBeforeCompanionThresholdStaysChapterOne() {
        XCTAssertEqual(GrowthStage.stage(forDistance: Companion.meetDistance - 1), 0)
        XCTAssertEqual(GrowthStage.chapterName(forDistance: Companion.meetDistance - 1), "第一章 · 啟程")
    }

    func testStageExactlyAtCompanionThresholdEntersChapterTwo() {
        XCTAssertEqual(GrowthStage.stage(forDistance: Companion.meetDistance), 1)
        XCTAssertEqual(GrowthStage.chapterName(forDistance: Companion.meetDistance), "第二章 · 有人同行")
    }

    func testStageJustBeforeThirdThresholdStaysChapterTwo() {
        XCTAssertEqual(GrowthStage.stage(forDistance: 432_000 - 1), 1)
    }

    func testStageExactlyAtThirdThresholdEntersChapterThree() {
        XCTAssertEqual(GrowthStage.stage(forDistance: 432_000), 2)
        XCTAssertEqual(GrowthStage.chapterName(forDistance: 432_000), "第三章 · 遠方的雪")
    }

    func testStageStaysAtLastChapterBeyondAllThresholds() {
        XCTAssertEqual(GrowthStage.stage(forDistance: 10_000_000), 2)
        XCTAssertEqual(GrowthStage.chapterName(forDistance: 10_000_000), "第三章 · 遠方的雪")
    }

    /// 單調：`distance` 增 → `stage` 不減（紅線一）。
    func testStageIsMonotonicNonDecreasing() {
        var previousStage = GrowthStage.stage(forDistance: 0)
        var distance: Double = 0
        while distance <= 600_000 {
            let stage = GrowthStage.stage(forDistance: distance)
            XCTAssertGreaterThanOrEqual(stage, previousStage)
            previousStage = stage
            distance += 12_345
        }
    }

    func testChapterNameIsDeterministic() {
        XCTAssertEqual(GrowthStage.chapterName(forDistance: 500_000), GrowthStage.chapterName(forDistance: 500_000))
    }

    // MARK: - chaptersCrossed（章節轉場偵測，同事件範式）

    func testChaptersCrossedNewNotGreaterThanOldReturnsEmpty() {
        XCTAssertTrue(GrowthStage.chaptersCrossed(from: 100, to: 100).isEmpty)
        XCTAssertTrue(GrowthStage.chaptersCrossed(from: 100, to: 50).isEmpty)
    }

    /// 門檻 0（第一章 · 啟程）為起始狀態、不算「跨越」：從 0 開始不觸發 0 門檻。
    func testStartingFromZeroDoesNotCrossFirstChapter() {
        let crossed = GrowthStage.chaptersCrossed(from: 0, to: 1_000)
        XCTAssertFalse(crossed.contains("第一章 · 啟程"))
        XCTAssertTrue(crossed.isEmpty)
    }

    func testCrossingCompanionThresholdReturnsChapterTwo() {
        let crossed = GrowthStage.chaptersCrossed(from: Companion.meetDistance - 1, to: Companion.meetDistance)
        XCTAssertEqual(crossed, ["第二章 · 有人同行"])
    }

    func testCrossingThirdThresholdReturnsChapterThree() {
        let crossed = GrowthStage.chaptersCrossed(from: 432_000 - 1, to: 432_000)
        XCTAssertEqual(crossed, ["第三章 · 遠方的雪"])
    }

    func testCrossingMultipleChaptersInOneStepReturnsAllInOrder() {
        let crossed = GrowthStage.chaptersCrossed(from: 0, to: 500_000)
        XCTAssertEqual(crossed, ["第二章 · 有人同行", "第三章 · 遠方的雪"])
    }

    func testChaptersCrossedIsDeterministic() {
        let a = GrowthStage.chaptersCrossed(from: 0, to: 500_000)
        let b = GrowthStage.chaptersCrossed(from: 0, to: 500_000)
        XCTAssertEqual(a, b)
    }

    /// 離線一次 settle == 線上逐 tick 的章節一致（迴歸鎖，承 T8 精神）。
    func testChaptersCrossedOnlineTickByTickMatchesOneShotAndOfflineSettle() {
        let rules = SimulationRules.default
        let totalSeconds: Double = 500_000 / rules.speed

        // 線上逐 tick 累積。
        var onlineState = GameState(distance: 0)
        var onlineChapters: [String] = []
        let stepSeconds: Double = 37
        var remaining = totalSeconds
        while remaining > 0 {
            let step = min(stepSeconds, remaining)
            let old = onlineState.distance
            let (next, _, _, _) = SimulationEngine.advance(onlineState, bySeconds: step, rules: rules)
            onlineChapters.append(contentsOf: GrowthStage.chaptersCrossed(from: old, to: next.distance))
            onlineState = next
            remaining -= step
        }

        // 一次計算。
        let oneShot = GrowthStage.chaptersCrossed(from: 0, to: onlineState.distance)
        XCTAssertEqual(onlineChapters, oneShot)

        // 離線一次 settle。
        let (_, outcome) = OfflineProgress.settle(GameState(distance: 0, lastActiveTimestamp: 0), now: totalSeconds, rules: rules)
        XCTAssertEqual(outcome.newChapters, onlineChapters)
    }
}
