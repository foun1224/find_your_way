import XCTest
@testable import FindYourWayCore

/// T9：旅伴相遇判定（`09_PHASE3_SPEC.md` §5 T9 / §3）。
final class CompanionTests: XCTestCase {

    let rules = SimulationRules.default

    func testHasMetFalseWhenNotYetReachingMeetDistance() {
        XCTAssertFalse(Companion.hasMet(crossedFrom: 0, to: Companion.meetDistance - 1))
    }

    func testHasMetTrueWhenCrossingMeetDistance() {
        XCTAssertTrue(Companion.hasMet(crossedFrom: Companion.meetDistance - 1, to: Companion.meetDistance + 1))
    }

    func testHasMetTrueWhenLandingExactlyOnMeetDistance() {
        XCTAssertTrue(Companion.hasMet(crossedFrom: Companion.meetDistance - 100, to: Companion.meetDistance))
    }

    func testHasMetFalseWhenAlreadyPastMeetDistance() {
        XCTAssertFalse(Companion.hasMet(crossedFrom: Companion.meetDistance, to: Companion.meetDistance + 100))
    }

    // MARK: - SimulationEngine.advance 整合：跨越 meetDistance → companionJoined 置 true

    func testAdvanceAcrossMeetDistanceSetsCompanionJoinedAndRecordsEvent() {
        let state = GameState(distance: Companion.meetDistance - 10)
        let secondsToCross = 20 / rules.speed

        let (newState, _, crossedEvents, companionJustJoined) = SimulationEngine.advance(
            state, bySeconds: secondsToCross, rules: rules
        )

        XCTAssertTrue(newState.companionJoined)
        XCTAssertTrue(companionJustJoined)
        XCTAssertTrue(crossedEvents.contains(where: { $0.id == Companion.meetEvent.id }))
        XCTAssertTrue(newState.eventsEncountered.contains(Companion.meetEvent.id))
    }

    /// 只觸發一次：多次結算 / 反覆推進 → 相遇事件不重複入 `eventsEncountered`，`companionJoined` 保持 true。
    func testCompanionMeetOnlyTriggersOnce() {
        var state = GameState(distance: Companion.meetDistance - 10)
        let secondsToCross = 20 / rules.speed

        let (afterFirst, _, _, firstJustJoined) = SimulationEngine.advance(
            state, bySeconds: secondsToCross, rules: rules
        )
        state = afterFirst
        XCTAssertTrue(firstJustJoined)

        let (afterSecond, _, secondEvents, secondJustJoined) = SimulationEngine.advance(
            state, bySeconds: 1_000, rules: rules
        )

        XCTAssertFalse(secondJustJoined)
        XCTAssertFalse(secondEvents.contains(where: { $0.id == Companion.meetEvent.id }))
        XCTAssertTrue(afterSecond.companionJoined)
        XCTAssertEqual(
            afterSecond.eventsEncountered.filter { $0 == Companion.meetEvent.id }.count,
            1
        )
    }

    /// 單調：`companionJoined` 一旦 true，後續任何 advance 不得轉 false。
    func testCompanionJoinedIsMonotonic() {
        var state = GameState(distance: Companion.meetDistance + 1)
        state.companionJoined = true

        for _ in 0..<20 {
            let (next, _, _, justJoined) = SimulationEngine.advance(state, bySeconds: 100, rules: rules)
            XCTAssertTrue(next.companionJoined)
            XCTAssertFalse(justJoined)
            state = next
        }
    }

    // MARK: - 離線相遇（走 OfflineProgress.settle 路徑）

    func testOfflineSettleAcrossMeetDistanceTriggersCompanionJoined() {
        let state = GameState(distance: 0, lastActiveTimestamp: 0)
        let secondsNeeded = (Companion.meetDistance + 10) / rules.speed
        let (newState, outcome) = OfflineProgress.settle(state, now: secondsNeeded, rules: rules)

        XCTAssertTrue(newState.companionJoined)
        XCTAssertTrue(outcome.companionJustJoined)
        XCTAssertTrue(outcome.newEvents.contains(where: { $0.id == Companion.meetEvent.id }))
    }
}
