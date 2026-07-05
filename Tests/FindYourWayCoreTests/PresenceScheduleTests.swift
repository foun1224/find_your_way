import XCTest
@testable import FindYourWayCore

final class PresenceScheduleTests: XCTestCase {

    // MARK: - P1c 陪你歇：`shouldRestTogether`

    func testShouldRestTogetherFalseBelowThreshold() {
        XCTAssertFalse(PresenceSchedule.shouldRestTogether(idleSeconds: PresenceSchedule.restIdleThresholdSeconds - 1))
    }

    func testShouldRestTogetherTrueAtThreshold() {
        XCTAssertTrue(PresenceSchedule.shouldRestTogether(idleSeconds: PresenceSchedule.restIdleThresholdSeconds))
    }

    func testShouldRestTogetherTrueWellAboveThreshold() {
        XCTAssertTrue(PresenceSchedule.shouldRestTogether(idleSeconds: PresenceSchedule.restIdleThresholdSeconds * 10))
    }

    func testShouldRestTogetherFalseAtZero() {
        XCTAssertFalse(PresenceSchedule.shouldRestTogether(idleSeconds: 0))
    }

    /// 門檻本身要遠大於歸來門檻（`22` §4 P1c「避開歷史 bug」：故意設長，區分「真的離開」
    /// 與「只是在看你/短暫停手」）。
    func testRestThresholdIsSignificantlyLongerThanReturnThreshold() {
        XCTAssertGreaterThan(
            PresenceSchedule.restIdleThresholdSeconds,
            PresenceSchedule.returnIdleThresholdSeconds * 2
        )
    }

    // MARK: - P1a 歸來的溫暖：`isReturnTransition`

    /// 核心情境：閒置了很久（≥ 門檻），然後活動恢復（閒置秒數變小）→ 算一次歸來。
    func testIsReturnTransitionTrueWhenLongIdleThenActivityResumes() {
        XCTAssertTrue(
            PresenceSchedule.isReturnTransition(
                previousIdleSeconds: PresenceSchedule.returnIdleThresholdSeconds + 30,
                currentIdleSeconds: 0
            )
        )
    }

    /// 邊界：剛好等於門檻也算「離開得夠久」。
    func testIsReturnTransitionTrueAtExactThreshold() {
        XCTAssertTrue(
            PresenceSchedule.isReturnTransition(
                previousIdleSeconds: PresenceSchedule.returnIdleThresholdSeconds,
                currentIdleSeconds: 0.5
            )
        )
    }

    /// 只是隨手按一下（閒置沒累積到門檻）就不該算「歸來」——不然每次打字都會觸發。
    func testIsReturnTransitionFalseWhenIdleNeverReachedThreshold() {
        XCTAssertFalse(
            PresenceSchedule.isReturnTransition(
                previousIdleSeconds: PresenceSchedule.returnIdleThresholdSeconds - 1,
                currentIdleSeconds: 0
            )
        )
    }

    /// 閒置秒數持續累積中（沒有輸入事件重置）不該被誤判成「歸來」——只有秒數變小才算剛活動過。
    func testIsReturnTransitionFalseWhileIdleKeepsIncreasing() {
        XCTAssertFalse(
            PresenceSchedule.isReturnTransition(
                previousIdleSeconds: PresenceSchedule.returnIdleThresholdSeconds + 30,
                currentIdleSeconds: PresenceSchedule.returnIdleThresholdSeconds + 35
            )
        )
    }

    /// 剛觸發過一次歸來之後，緊接著的下一次輪詢（`previous` 已經很小）不會重複觸發——
    /// 天然自我去重（不需要額外冷卻就不會連續觸發，冷卻是為了跨路徑而非同路徑重觸發）。
    func testIsReturnTransitionFalseImmediatelyAfterAlreadyReturned() {
        XCTAssertFalse(
            PresenceSchedule.isReturnTransition(previousIdleSeconds: 0.5, currentIdleSeconds: 0.1)
        )
    }

    func testIsReturnTransitionFalseWhenBothZero() {
        XCTAssertFalse(PresenceSchedule.isReturnTransition(previousIdleSeconds: 0, currentIdleSeconds: 0))
    }

    // MARK: - 冷卻：`canTriggerReturnWelcome`

    func testCanTriggerReturnWelcomeTrueWhenNeverTriggeredBefore() {
        XCTAssertTrue(PresenceSchedule.canTriggerReturnWelcome(now: 100, lastTriggerTime: -.infinity))
    }

    func testCanTriggerReturnWelcomeFalseWithinCooldown() {
        XCTAssertFalse(
            PresenceSchedule.canTriggerReturnWelcome(
                now: 100,
                lastTriggerTime: 100 - PresenceSchedule.returnWelcomeCooldownSeconds + 1
            )
        )
    }

    func testCanTriggerReturnWelcomeTrueExactlyAtCooldownBoundary() {
        XCTAssertTrue(
            PresenceSchedule.canTriggerReturnWelcome(
                now: 100,
                lastTriggerTime: 100 - PresenceSchedule.returnWelcomeCooldownSeconds
            )
        )
    }

    func testCanTriggerReturnWelcomeTrueLongAfterCooldown() {
        XCTAssertTrue(
            PresenceSchedule.canTriggerReturnWelcome(
                now: 1000,
                lastTriggerTime: 0
            )
        )
    }
}
