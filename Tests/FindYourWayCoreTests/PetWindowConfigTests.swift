import XCTest
@testable import FindYourWayCore
#if canImport(AppKit)
import AppKit
#endif

final class PetWindowConfigTests: XCTestCase {

    func testBottomRightOriginAnchoredWithMargin() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        let margin = CGSize(width: 24, height: 24)

        let origin = PetWindowConfig.bottomRightOrigin(
            visibleFrame: visibleFrame,
            windowSize: windowSize,
            margin: margin
        )

        XCTAssertEqual(origin.x, 1440 - 320 - 24, accuracy: 0.0001)
        XCTAssertEqual(origin.y, 0 + 24, accuracy: 0.0001)
    }

    func testBottomRightOriginFallsWithinVisibleFrameBottomRightQuadrant() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = PetWindowConfig.defaultSize
        let origin = PetWindowConfig.bottomRightOrigin(visibleFrame: visibleFrame)

        // 落在右下角：x 落在畫面右半、y 落在畫面下半。
        XCTAssertGreaterThan(origin.x, visibleFrame.midX)
        XCTAssertLessThan(origin.y, visibleFrame.midY)

        // 視窗完整 frame 不超出可視範圍。
        let frame = CGRect(origin: origin, size: windowSize)
        XCTAssertTrue(visibleFrame.contains(frame))
    }

    func testBottomRightOriginRespectsNonZeroScreenOrigin() {
        // 模擬非主螢幕（visibleFrame.origin 不是 (0,0)）的情境。
        let visibleFrame = CGRect(x: 100, y: 50, width: 1440, height: 900)
        let windowSize = CGSize(width: 320, height: 180)
        let margin = CGSize(width: 24, height: 24)

        let origin = PetWindowConfig.bottomRightOrigin(
            visibleFrame: visibleFrame,
            windowSize: windowSize,
            margin: margin
        )

        XCTAssertEqual(origin.x, visibleFrame.maxX - windowSize.width - margin.width, accuracy: 0.0001)
        XCTAssertEqual(origin.y, visibleFrame.minY + margin.height, accuracy: 0.0001)
    }

    func testReanchorsAfterScreenParametersChange_externalMonitorRemoved() {
        // 模擬「原本橫跨外接大螢幕，拔掉後主螢幕變小」的螢幕參數變更（`10` §7）：
        // 重新以新的 visibleFrame 計算，桌寵應落在新螢幕右下角、不越界、不殘留舊座標。
        let externalVisibleFrame = CGRect(x: 0, y: 0, width: 3440, height: 1440)
        let windowSize = PetWindowConfig.defaultSize
        let originBefore = PetWindowConfig.bottomRightOrigin(visibleFrame: externalVisibleFrame, windowSize: windowSize)

        let fallbackVisibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let originAfter = PetWindowConfig.bottomRightOrigin(visibleFrame: fallbackVisibleFrame, windowSize: windowSize)

        XCTAssertNotEqual(originBefore, originAfter)

        let frameAfter = CGRect(origin: originAfter, size: windowSize)
        XCTAssertTrue(fallbackVisibleFrame.contains(frameAfter))
    }

    func testReanchorsWithinNonZeroOriginScreenAfterChange() {
        // 主螢幕消失、退回一個 origin 非 (0,0) 的可用螢幕（`10` §7 fallback）。
        let visibleFrame = CGRect(x: 200, y: 100, width: 1280, height: 800)
        let windowSize = PetWindowConfig.defaultSize
        let frame = PetWindowConfig.bottomRightFrame(visibleFrame: visibleFrame, windowSize: windowSize)

        XCTAssertTrue(visibleFrame.contains(frame))
        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY)
    }

    #if canImport(AppKit)
    func testWindowFlagsMatchArchitectureSpec() {
        XCTAssertEqual(PetWindowConfig.Flags.styleMask, [.borderless])
        XCTAssertFalse(PetWindowConfig.Flags.isOpaque)
        XCTAssertEqual(PetWindowConfig.Flags.backgroundColor, NSColor.clear)
        XCTAssertFalse(PetWindowConfig.Flags.hasShadow)
        XCTAssertEqual(PetWindowConfig.Flags.level, .floating)
        XCTAssertTrue(PetWindowConfig.Flags.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(PetWindowConfig.Flags.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(PetWindowConfig.Flags.ignoresMouseEvents)
        XCTAssertFalse(PetWindowConfig.Flags.isMovableByWindowBackground)
        XCTAssertFalse(PetWindowConfig.Flags.canBecomeKey)
    }
    #endif
}
