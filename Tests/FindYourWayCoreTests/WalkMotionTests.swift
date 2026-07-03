import XCTest
@testable import FindYourWayCore

/// ADR-009：`WalkMotion.position` 語意從「螢幕 x 座標（含邊界折返）」改為
/// 「概念里程（distance），單調不減、無邊界」。本檔測試已隨語意更新：
/// 移除舊有的左右 roam / 邊界折返 / 方向反轉斷言（該行為已不存在），
/// 改為驗證「恆向前推進」「dt<=0/速度為 0 不動」「累加無偏差」等新語意下仍成立的不變式。
final class WalkMotionTests: XCTestCase {

    func testStepAdvancesPositionForward() {
        var motion = WalkMotion(position: 0, speed: 10)
        motion.step(dt: 1.0)
        XCTAssertEqual(motion.position, 10, accuracy: 0.0001)
    }

    func testStepNeverMovesBackward() {
        var motion = WalkMotion(position: 50, speed: 10)
        motion.step(dt: 3.0)
        XCTAssertEqual(motion.position, 80, accuracy: 0.0001)
        // 再推進，位置只增不減。
        motion.step(dt: 1.0)
        XCTAssertGreaterThan(motion.position, 80)
    }

    func testZeroOrNegativeDtDoesNotChangePosition() {
        var motion = WalkMotion(position: 0, speed: 10)
        motion.step(dt: 0)
        XCTAssertEqual(motion.position, 0, accuracy: 0.0001)
        motion.step(dt: -1)
        XCTAssertEqual(motion.position, 0, accuracy: 0.0001)
    }

    func testZeroSpeedNeverMoves() {
        var motion = WalkMotion(position: 0, speed: 0)
        motion.step(dt: 5)
        XCTAssertEqual(motion.position, 0, accuracy: 0.0001)
    }

    func testNegativeInitialPositionIsClampedToZero() {
        let motion = WalkMotion(position: -50, speed: 10)
        XCTAssertEqual(motion.position, 0, accuracy: 0.0001)
    }

    func testMultipleSmallStepsEqualsOneLargeStep() {
        var stepped = WalkMotion(position: 0, speed: 10)
        for _ in 0..<10 {
            stepped.step(dt: 0.1)
        }
        var single = WalkMotion(position: 0, speed: 10)
        single.step(dt: 1.0)
        XCTAssertEqual(stepped.position, single.position, accuracy: 0.0001)
    }
}
