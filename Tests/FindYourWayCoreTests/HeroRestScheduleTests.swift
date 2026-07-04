import XCTest
@testable import FindYourWayCore

final class HeroRestScheduleTests: XCTestCase {

    func testNextIntervalSecondsAtZeroUnitEqualsMin() {
        XCTAssertEqual(
            HeroRestSchedule.nextIntervalSeconds(unit: 0),
            HeroRestSchedule.minIntervalSeconds,
            accuracy: 0.0001
        )
    }

    func testNextIntervalSecondsAtOneUnitEqualsMax() {
        XCTAssertEqual(
            HeroRestSchedule.nextIntervalSeconds(unit: 1),
            HeroRestSchedule.maxIntervalSeconds,
            accuracy: 0.0001
        )
    }

    func testNextIntervalSecondsIsMonotonicWithUnit() {
        var previous = HeroRestSchedule.nextIntervalSeconds(unit: 0)
        for unit in stride(from: 0.1, through: 1.0, by: 0.1) {
            let current = HeroRestSchedule.nextIntervalSeconds(unit: unit)
            XCTAssertGreaterThanOrEqual(current, previous)
            previous = current
        }
    }

    func testNextIntervalSecondsClampsOutOfRangeUnit() {
        XCTAssertEqual(
            HeroRestSchedule.nextIntervalSeconds(unit: -5),
            HeroRestSchedule.minIntervalSeconds,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HeroRestSchedule.nextIntervalSeconds(unit: 5),
            HeroRestSchedule.maxIntervalSeconds,
            accuracy: 0.0001
        )
    }

    func testNextIntervalSecondsAlwaysWithinBounds() {
        for unit in stride(from: 0.0, through: 1.0, by: 0.05) {
            let value = HeroRestSchedule.nextIntervalSeconds(unit: unit)
            XCTAssertGreaterThanOrEqual(value, HeroRestSchedule.minIntervalSeconds)
            XCTAssertLessThanOrEqual(value, HeroRestSchedule.maxIntervalSeconds)
        }
    }

    func testRestDurationSecondsAtZeroUnitEqualsMin() {
        XCTAssertEqual(
            HeroRestSchedule.restDurationSeconds(unit: 0),
            HeroRestSchedule.minRestDurationSeconds,
            accuracy: 0.0001
        )
    }

    func testRestDurationSecondsAtOneUnitEqualsMax() {
        XCTAssertEqual(
            HeroRestSchedule.restDurationSeconds(unit: 1),
            HeroRestSchedule.maxRestDurationSeconds,
            accuracy: 0.0001
        )
    }

    func testRestDurationSecondsClampsOutOfRangeUnit() {
        XCTAssertEqual(
            HeroRestSchedule.restDurationSeconds(unit: -1),
            HeroRestSchedule.minRestDurationSeconds,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HeroRestSchedule.restDurationSeconds(unit: 2),
            HeroRestSchedule.maxRestDurationSeconds,
            accuracy: 0.0001
        )
    }

    func testRestDurationSecondsAlwaysWithinBounds() {
        for unit in stride(from: 0.0, through: 1.0, by: 0.05) {
            let value = HeroRestSchedule.restDurationSeconds(unit: unit)
            XCTAssertGreaterThanOrEqual(value, HeroRestSchedule.minRestDurationSeconds)
            XCTAssertLessThanOrEqual(value, HeroRestSchedule.maxRestDurationSeconds)
        }
    }

    /// 低喚醒守則（`02` §6）：轉場/追趕時間應維持在「慢、無 jolt」的短秒數區間，
    /// 不應被誤改成大到會讓人覺得「卡頓」的值。
    func testTransitionAndCatchUpDurationsAreShortAndCalm() {
        XCTAssertGreaterThan(HeroRestSchedule.transitionDurationSeconds, 0)
        XCTAssertLessThanOrEqual(HeroRestSchedule.transitionDurationSeconds, 1.0)
        XCTAssertGreaterThanOrEqual(HeroRestSchedule.catchUpDurationSeconds, 0.4)
        XCTAssertLessThanOrEqual(HeroRestSchedule.catchUpDurationSeconds, 0.6)
    }
}
