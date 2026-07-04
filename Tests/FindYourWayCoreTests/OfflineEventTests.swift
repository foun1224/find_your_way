import XCTest
@testable import FindYourWayCore

/// T8：離線事件補算——**靈魂測試**，承 `08` T2「在線=離線同速」精神，
/// 擴充到里程事件（`09_PHASE3_SPEC.md` §5 T8 / §2.4）。
final class OfflineEventTests: XCTestCase {

    let rules = SimulationRules.default

    /// 離線=線上事件一致（迴歸鎖）：`settle(elapsed=T)` 收集的 `newEvents`
    /// 必須 == 線上逐 tick 走完同 `distance` 收集的事件（依里程排序、去重後比較）。
    func testOfflineNewEventsMatchOnlineTickByTickAccumulation() {
        // 走到涵蓋前三個事件 + 跨越旅伴相遇的距離。
        let totalSeconds: Double = (Companion.meetDistance + 50_000) / rules.speed

        // 線上：以小步逐 tick 走完同樣秒數，逐次累積 crossedEvents。
        var onlineState = GameState(distance: 0)
        var onlineCrossedIds: [String] = []
        let stepSeconds: Double = 37 // 刻意用不整除的步長，模擬真實 tick 抖動。
        var remaining = totalSeconds
        while remaining > 0 {
            let step = min(stepSeconds, remaining)
            let (next, _, crossedEvents, _) = SimulationEngine.advance(onlineState, bySeconds: step, rules: rules)
            onlineCrossedIds.append(contentsOf: crossedEvents.map(\.id))
            onlineState = next
            remaining -= step
        }

        // 離線：一次 settle 同樣秒數。
        let offlineState = GameState(distance: 0, lastActiveTimestamp: 0)
        let (settledState, outcome) = OfflineProgress.settle(offlineState, now: totalSeconds, rules: rules)

        XCTAssertEqual(outcome.newEvents.map(\.id), onlineCrossedIds)
        XCTAssertEqual(settledState.eventsEncountered, onlineState.eventsEncountered)
        XCTAssertEqual(settledState.companionJoined, onlineState.companionJoined)
        XCTAssertEqual(settledState.distance, onlineState.distance, accuracy: 0.0001)
    }

    /// 確定性可重現：相同 `(state, now)` 呼叫兩次，`newEvents` 逐元素相等（無 `now`-seeded 隨機）。
    func testDeterministicSameInputsProduceSameNewEvents() {
        let state = GameState(distance: 100, lastActiveTimestamp: 1_000)
        let now: Double = 1_000 + (300_000 / rules.speed)

        let (stateA, outcomeA) = OfflineProgress.settle(state, now: now, rules: rules)
        let (stateB, outcomeB) = OfflineProgress.settle(state, now: now, rules: rules)

        XCTAssertEqual(outcomeA.newEvents, outcomeB.newEvents)
        XCTAssertEqual(stateA.eventsEncountered, stateB.eventsEncountered)
        XCTAssertEqual(outcomeA.companionJustJoined, outcomeB.companionJustJoined)
    }

    /// `wasCapped` 不吞事件：超上限截斷只結算 12h 份量事件；未走到的事件不消失
    /// （下次繼續走會遇到），也不得在此次 outcome 中「假裝」補上超出 cap 的事件。
    ///
    /// 用較低速率的 `rules`（不動全域預設常數）讓 12h cap 的里程落在事件表中間，
    /// 才能在現有 authored 事件表上真正演練「截斷」情境。
    func testWasCappedOnlySettlesEventsWithinCappedDistanceAndLaterCatchesRest() {
        let slowRules = SimulationRules(speed: 0.5) // capSeconds(43200) × 0.5 = 21600 < 43200(第一個事件)
        let farBeyondCapSeconds = OfflineProgress.capSeconds * 100
        let state = GameState(distance: 0, lastActiveTimestamp: 0)

        let (cappedState, outcome) = OfflineProgress.settle(state, now: farBeyondCapSeconds, rules: slowRules)
        XCTAssertTrue(outcome.wasCapped)

        let cappedDistance = slowRules.distanceGained(overSeconds: OfflineProgress.capSeconds)
        let expectedEvents = slowRules.events(crossedFrom: 0, to: cappedDistance)
        XCTAssertEqual(
            outcome.newEvents.filter { $0.id != Companion.meetEvent.id }.map(\.id),
            expectedEvents.map(\.id)
        )

        // 事件表中「超出這次 capped 里程」的事件，此次不應出現。
        let beyondCapEvents = JourneyEvent.all.filter { $0.distance > cappedDistance }
        XCTAssertFalse(beyondCapEvents.isEmpty, "測試前提：需要有超出 capped 里程的事件才能驗證截斷語意")
        for beyond in beyondCapEvents {
            XCTAssertFalse(outcome.newEvents.contains(where: { $0.id == beyond.id }))
            XCTAssertFalse(cappedState.eventsEncountered.contains(beyond.id))
        }

        // 繼續走（重複 settle）最終會遇到剩下的每一個事件——「還沒走到」而非「永久錯過」（紅線二）。
        var walkingState = cappedState
        var walkingNow = farBeyondCapSeconds
        for _ in 0..<30 {
            walkingNow += OfflineProgress.capSeconds
            let (next, _) = OfflineProgress.settle(walkingState, now: walkingNow, rules: slowRules)
            walkingState = next
        }
        for beyond in beyondCapEvents {
            XCTAssertTrue(walkingState.eventsEncountered.contains(beyond.id))
        }
    }

    /// 只增不減：`eventsEncountered` 任意序列後單調不減、不移除既有元素。
    func testEventsEncounteredIsMonotonicAcrossMultipleSettles() {
        var state = GameState(distance: 0, lastActiveTimestamp: 0)
        var now: Double = 0
        var previousCount = 0

        for _ in 0..<10 {
            now += 50_000 / rules.speed
            let (next, _) = OfflineProgress.settle(state, now: now, rules: rules)
            XCTAssertGreaterThanOrEqual(next.eventsEncountered.count, previousCount)

            // 不移除既有元素：先前已記錄的 id 仍全部存在。
            let previousIds = Set(state.eventsEncountered)
            XCTAssertTrue(previousIds.isSubset(of: Set(next.eventsEncountered)))

            previousCount = next.eventsEncountered.count
            state = next
        }
    }

    /// 無 `now`-seeded 隨機的工程落地：事件序列只取決於 `(oldDistance, newDistance]`，
    /// 用完全不同的「牆鐘」餵入（但相同的 elapsed 秒數）必須得到相同結果。
    func testEventsDependOnlyOnDistanceIntervalNotWallClock() {
        let elapsed: Double = 250_000 / rules.speed

        let stateA = GameState(distance: 0, lastActiveTimestamp: 1_000)
        let (_, outcomeA) = OfflineProgress.settle(stateA, now: 1_000 + elapsed, rules: rules)

        let stateB = GameState(distance: 0, lastActiveTimestamp: 9_999_999)
        let (_, outcomeB) = OfflineProgress.settle(stateB, now: 9_999_999 + elapsed, rules: rules)

        XCTAssertEqual(outcomeA.newEvents, outcomeB.newEvents)
    }
}
