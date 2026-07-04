import XCTest
@testable import FindYourWayCore

final class WindowDragGestureTests: XCTestCase {

    func testNoMovementDoesNotExceedThreshold() {
        XCTAssertFalse(WindowDragGesture.exceedsThreshold(dx: 0, dy: 0))
    }

    func testTinyJitterUnderThresholdDoesNotCountAsDrag() {
        // 手震級的微幅位移（< 4pt 預設門檻）仍應判定為點擊，不誤判成拖曳。
        XCTAssertFalse(WindowDragGesture.exceedsThreshold(dx: 1, dy: 1))
        XCTAssertFalse(WindowDragGesture.exceedsThreshold(dx: 3, dy: 0))
    }

    func testMovementPastThresholdCountsAsDrag() {
        XCTAssertTrue(WindowDragGesture.exceedsThreshold(dx: 10, dy: 0))
        XCTAssertTrue(WindowDragGesture.exceedsThreshold(dx: 0, dy: 10))
        XCTAssertTrue(WindowDragGesture.exceedsThreshold(dx: 3, dy: 3))
    }

    func testCustomThresholdIsRespected() {
        XCTAssertFalse(WindowDragGesture.exceedsThreshold(dx: 5, dy: 0, threshold: 10))
        XCTAssertTrue(WindowDragGesture.exceedsThreshold(dx: 15, dy: 0, threshold: 10))
    }

    func testExactlyAtThresholdIsNotYetExceeded() {
        // 邊界值：等於門檻視為「還沒超過」（尚未確定是拖曳），避免邊界抖動誤判。
        XCTAssertFalse(WindowDragGesture.exceedsThreshold(dx: 4, dy: 0, threshold: 4))
    }
}
