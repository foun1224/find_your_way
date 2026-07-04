import XCTest
@testable import FindYourWayCore

final class ProximityAwarenessTests: XCTestCase {

    private let characterScreenX = 80.0
    private let characterScreenY = 40.0
    private let characterSize = CGSize(width: 30, height: 44)
    private let sceneSize = CGSize(width: 320, height: 180)

    // MARK: - isNear：比命中框大一圈

    func testPointJustOutsideHitPaddingButWithinProximityRadiusIsNear() {
        // 剛好超出點擊命中框（`CharacterHitTest`）的容差，但仍在靠近感應圈內。
        let farX = characterScreenX + characterSize.width / 2 + CharacterHitTest.hitPadding + 1
        let point = CGPoint(x: farX, y: characterScreenY + 10)

        XCTAssertFalse(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ), "precondition：這個點不該落在點擊命中框內")

        XCTAssertTrue(ProximityAwareness.isNear(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointFarBeyondProximityRadiusIsNotNear() {
        let point = CGPoint(x: 300, y: 170)
        XCTAssertFalse(ProximityAwareness.isNear(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointJustOutsideProximityRadiusIsMiss() {
        let farX = characterScreenX + characterSize.width / 2 + ProximityAwareness.totalPadding + 1
        let point = CGPoint(x: farX, y: characterScreenY + 10)
        XCTAssertFalse(ProximityAwareness.isNear(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointOutsideSceneBoundsIsNeverNear() {
        let point = CGPoint(x: -5, y: characterScreenY)
        XCTAssertFalse(ProximityAwareness.isNear(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testCenterOfCharacterIsNear() {
        let point = CGPoint(x: characterScreenX, y: characterScreenY + characterSize.height / 2)
        XCTAssertTrue(ProximityAwareness.isNear(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    // MARK: - shouldAcknowledge：邊緣觸發 + 節流冷卻

    func testShouldAcknowledgeOnFreshEntryWithNoPriorTrigger() {
        XCTAssertTrue(ProximityAwareness.shouldAcknowledge(
            wasNear: false,
            isNear: true,
            now: 100,
            lastAcknowledgeTime: -.infinity
        ))
    }

    func testShouldNotAcknowledgeWhenAlreadyNear() {
        // 游標持續停留在感應圈內（edge-triggered：wasNear 也是 true）→ 不重複觸發。
        XCTAssertFalse(ProximityAwareness.shouldAcknowledge(
            wasNear: true,
            isNear: true,
            now: 100,
            lastAcknowledgeTime: -.infinity
        ))
    }

    func testShouldNotAcknowledgeWhenNotNear() {
        XCTAssertFalse(ProximityAwareness.shouldAcknowledge(
            wasNear: false,
            isNear: false,
            now: 100,
            lastAcknowledgeTime: -.infinity
        ))
    }

    func testShouldNotAcknowledgeWhenLeaving() {
        XCTAssertFalse(ProximityAwareness.shouldAcknowledge(
            wasNear: true,
            isNear: false,
            now: 100,
            lastAcknowledgeTime: -.infinity
        ))
    }

    func testShouldNotAcknowledgeDuringCooldown() {
        let lastTrigger = 100.0
        let now = lastTrigger + ProximityAwareness.cooldownSeconds - 1
        XCTAssertFalse(ProximityAwareness.shouldAcknowledge(
            wasNear: false,
            isNear: true,
            now: now,
            lastAcknowledgeTime: lastTrigger
        ))
    }

    func testShouldAcknowledgeAfterCooldownElapses() {
        let lastTrigger = 100.0
        let now = lastTrigger + ProximityAwareness.cooldownSeconds
        XCTAssertTrue(ProximityAwareness.shouldAcknowledge(
            wasNear: false,
            isNear: true,
            now: now,
            lastAcknowledgeTime: lastTrigger
        ))
    }

    func testRepeatedNearEntryAfterLeavingAndReenteringRespectsCooldown() {
        // 模擬：靠近觸發 → 離開 → 冷卻內立刻再靠近（不該再觸發）→ 冷卻後再靠近（該觸發）。
        let firstTriggerTime = 0.0
        XCTAssertTrue(ProximityAwareness.shouldAcknowledge(
            wasNear: false, isNear: true, now: firstTriggerTime, lastAcknowledgeTime: -.infinity
        ))

        let leaveThenReenterTooSoon = ProximityAwareness.cooldownSeconds - 5
        XCTAssertFalse(ProximityAwareness.shouldAcknowledge(
            wasNear: false, isNear: true, now: leaveThenReenterTooSoon, lastAcknowledgeTime: firstTriggerTime
        ))

        let leaveThenReenterAfterCooldown = ProximityAwareness.cooldownSeconds + 5
        XCTAssertTrue(ProximityAwareness.shouldAcknowledge(
            wasNear: false, isNear: true, now: leaveThenReenterAfterCooldown, lastAcknowledgeTime: firstTriggerTime
        ))
    }
}
