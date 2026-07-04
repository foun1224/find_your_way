import XCTest
@testable import FindYourWayCore

/// T7：里程事件觸發（`09_PHASE3_SPEC.md` §5 T7），純函式、同 `landmarks(crossedFrom:to:)` 範式。
final class JourneyEventTests: XCTestCase {

    let rules = SimulationRules.default

    func testEventsAreSortedAscendingByDistance() {
        let distances = JourneyEvent.all.map(\.distance)
        XCTAssertEqual(distances, distances.sorted())
    }

    func testEventIdsAreUnique() {
        let ids = JourneyEvent.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testNewGreaterThanOldReturnsEmpty() {
        XCTAssertTrue(rules.events(crossedFrom: 100, to: 100).isEmpty)
        XCTAssertTrue(rules.events(crossedFrom: 100, to: 50).isEmpty)
    }

    func testReturnsEventsStrictlyWithinOldExclusiveNewInclusiveRange() {
        let first = JourneyEvent.all[0]
        let crossed = rules.events(crossedFrom: 0, to: first.distance)
        XCTAssertEqual(crossed.map(\.id), [first.id])

        // 剛好在事件里程上不算「已通過」（old 不含）。
        let notYet = rules.events(crossedFrom: first.distance, to: first.distance)
        XCTAssertTrue(notYet.isEmpty)
    }

    func testCrossingMultipleEventsInOneStepReturnsAllInOrder() {
        let first = JourneyEvent.all[0]
        let second = JourneyEvent.all[1]
        let crossed = rules.events(crossedFrom: 0, to: second.distance)
        XCTAssertEqual(crossed.map(\.id), [first.id, second.id])
    }

    func testRepeatedCallsAreDeterministic() {
        let a = rules.events(crossedFrom: 0, to: 500_000)
        let b = rules.events(crossedFrom: 0, to: 500_000)
        XCTAssertEqual(a, b)
    }

    func testEventsBeyondLastEventReturnEmpty() {
        let last = JourneyEvent.all.last!
        let crossed = rules.events(crossedFrom: last.distance, to: last.distance + 10_000)
        XCTAssertTrue(crossed.isEmpty)
    }

    /// 零功利（ADR-006）：事件表沒有任何隱含的資源/加速欄位——資料結構本身只含
    /// id/kind/distance/logText，無法表達功利回報。
    func testEventOnlyCarriesNarrativeFields() {
        for event in JourneyEvent.all {
            XCTAssertFalse(event.logText.isEmpty)
        }
    }
}
