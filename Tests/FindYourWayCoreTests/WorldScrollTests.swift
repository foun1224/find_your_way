import XCTest
@testable import FindYourWayCore

final class WorldScrollTests: XCTestCase {

    func testScrollOffsetMovesNegativelyAsDistanceIncreases() {
        let offsetAt0 = WorldScroll.scrollOffset(forDistance: 0, layerFactor: 1.0)
        let offsetAt100 = WorldScroll.scrollOffset(forDistance: 100, layerFactor: 1.0)

        XCTAssertEqual(offsetAt0, 0)
        XCTAssertLessThan(offsetAt100, offsetAt0) // 世界向左捲：偏移越來越負
    }

    func testScrollOffsetIsMonotonicWithDistance() {
        var previous = WorldScroll.scrollOffset(forDistance: 0, layerFactor: 0.5)
        for distance in stride(from: 10.0, through: 100.0, by: 10.0) {
            let current = WorldScroll.scrollOffset(forDistance: distance, layerFactor: 0.5)
            XCTAssertLessThan(current, previous)
            previous = current
        }
    }

    func testDifferentLayerFactorsProduceDifferentScrollAmounts() {
        let distance = 200.0
        let farLayer = WorldScroll.scrollOffset(forDistance: distance, layerFactor: 0.1) // 遠景慢
        let nearLayer = WorldScroll.scrollOffset(forDistance: distance, layerFactor: 1.0) // 近景快

        XCTAssertGreaterThan(abs(nearLayer), abs(farLayer))
    }

    func testLandmarkScreenXAlignsWithCharacterWhenReached() {
        let anchorX = 100.0
        let x = WorldScroll.landmarkScreenX(landmarkDistance: 500, currentDistance: 500, characterAnchorX: anchorX)
        XCTAssertEqual(x, anchorX, accuracy: 0.0001)
    }

    func testLandmarkScreenXMovesLeftAsCurrentDistanceApproaches() {
        let anchorX = 100.0
        let landmarkDistance = 1_000.0

        let farX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 0, characterAnchorX: anchorX)
        let closerX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 500, characterAnchorX: anchorX)
        let atX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 1_000, characterAnchorX: anchorX)

        XCTAssertGreaterThan(farX, closerX)
        XCTAssertGreaterThan(closerX, atX)
        XCTAssertEqual(atX, anchorX, accuracy: 0.0001)
    }

    func testLandmarkScreenXContinuesMovingLeftAfterPassing() {
        let anchorX = 100.0
        let landmarkDistance = 1_000.0

        let atX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 1_000, characterAnchorX: anchorX)
        let passedX = WorldScroll.landmarkScreenX(landmarkDistance: landmarkDistance, currentDistance: 1_200, characterAnchorX: anchorX)

        XCTAssertLessThan(passedX, atX)
    }

    // MARK: - 可循環佔位景物 wrap（`08` §4b）

    func testWrappedXStaysWithinSpan() {
        let span = 400.0
        for distance in stride(from: 0.0, through: 2_000.0, by: 37.0) {
            let x = WorldScroll.wrappedX(baseX: 120, distance: distance, layerFactor: 1.0, span: span)
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThan(x, span)
        }
    }

    func testWrappedXMovesLeftAsDistanceIncreasesWithinOnePeriod() {
        let span = 400.0
        // 在一個週期內（未 wrap 前），distance 增加 → x 遞減（往左移）。
        let x0 = WorldScroll.wrappedX(baseX: 300, distance: 0, layerFactor: 1.0, span: span)
        let x1 = WorldScroll.wrappedX(baseX: 300, distance: 50, layerFactor: 1.0, span: span)
        let x2 = WorldScroll.wrappedX(baseX: 300, distance: 100, layerFactor: 1.0, span: span)
        XCTAssertLessThan(x1, x0)
        XCTAssertLessThan(x2, x1)
    }

    func testWrappedXIsPeriodicOverSpan() {
        let span = 400.0
        let baseX = 150.0
        // 位移剛好一個 span（distance*layerFactor == span）→ 回到起點。
        let x0 = WorldScroll.wrappedX(baseX: baseX, distance: 0, layerFactor: 1.0, span: span)
        let xSpan = WorldScroll.wrappedX(baseX: baseX, distance: span, layerFactor: 1.0, span: span)
        XCTAssertEqual(x0, xSpan, accuracy: 0.0001)
    }

    func testWrappedXWrapsBackToRightAfterCrossingZero() {
        let span = 400.0
        // baseX 很小，稍微位移就越過 0 → wrap 到接近 span（右側重新進場）。
        let x = WorldScroll.wrappedX(baseX: 10, distance: 50, layerFactor: 1.0, span: span)
        XCTAssertEqual(x, 360, accuracy: 0.0001) // 10 - 50 = -40 → +400 = 360
    }

    func testWrappedXDifferentLayerFactorsScrollAtDifferentRates() {
        let span = 400.0
        let distance = 100.0
        let far = WorldScroll.wrappedX(baseX: 300, distance: distance, layerFactor: 0.3, span: span)
        let near = WorldScroll.wrappedX(baseX: 300, distance: distance, layerFactor: 1.0, span: span)
        // 近景移動較多（離基準槽位更遠）。
        XCTAssertGreaterThan(300 - near, 300 - far)
    }

    func testWrappedXZeroSpanReturnsBaseX() {
        let x = WorldScroll.wrappedX(baseX: 42, distance: 999, layerFactor: 1.0, span: 0)
        XCTAssertEqual(x, 42, accuracy: 0.0001)
    }

    // MARK: - Panorama 無縫水平平鋪（Phase 4a 背景全黑 bug 迴歸鎖）
    //
    // 根因：panorama 曾誤用 `wrappedX`（各槽位獨立 mod span），distance 一增加，
    // 兩張 tile 就一起被繞到可視範圍外 → 整片透空變黑。`panoramaTileXs` 改以
    // tile 寬度為平鋪單位；下面驗證任何 distance 下 tile 聯集都完整覆蓋 `[0, sceneWidth]`。

    /// 給定 tile 左緣陣列與寬度，回傳是否完整覆蓋 `[0, sceneWidth]`（用細緻取樣點檢查每點都落在某張 tile 內）。
    private func coversFullRange(_ xs: [Double], tileWidth: Double, sceneWidth: Double) -> Bool {
        let sampleStep = 1.0
        var sample = 0.0
        while sample <= sceneWidth {
            let covered = xs.contains { x in sample >= x && sample < x + tileWidth }
            if !covered { return false }
            sample += sampleStep
        }
        return true
    }

    func testPanoramaTileXsCoversFullSceneWidthAtVariousDistances() {
        let sceneWidth = 320.0
        let tileWidth = 784.0
        let layerFactor = 1.0

        // 涵蓋：0、tile 邊界附近、多個 tile 之後的大 distance、負向（理論上不會發生但要防呆）。
        let distances: [Double] = [
            0, 1, 100, 392,
            tileWidth - 0.001, tileWidth, tileWidth + 1,
            2 * tileWidth, 10_000, 1_000_000,
            -1, -tileWidth, -12345,
        ]

        for distance in distances {
            let xs = WorldScroll.panoramaTileXs(
                sceneWidth: sceneWidth, tileWidth: tileWidth, distance: distance, layerFactor: layerFactor
            )
            XCTAssertTrue(
                coversFullRange(xs, tileWidth: tileWidth, sceneWidth: sceneWidth),
                "distance=\(distance) 時 tiles=\(xs) 未完整覆蓋 [0, \(sceneWidth)]（會露空變黑）"
            )
        }
    }

    func testPanoramaTileXsCoversFullRangeAcrossContinuousSweep() {
        // 連續掃過多個週期，確保「任意極小 shift」都不會露空（原 bug 的實際觸發情境：每個 2 秒 tick 位移一點點）。
        let sceneWidth = 320.0
        let tileWidth = 784.0
        for distance in stride(from: 0.0, through: 3 * tileWidth, by: 5.0) {
            let xs = WorldScroll.panoramaTileXs(
                sceneWidth: sceneWidth, tileWidth: tileWidth, distance: distance, layerFactor: 0.45
            )
            XCTAssertTrue(
                coversFullRange(xs, tileWidth: tileWidth, sceneWidth: sceneWidth),
                "distance=\(distance) 時未完整覆蓋"
            )
        }
    }

    func testPanoramaTileXsDifferentLayerFactorsAllCoverFullRange() {
        let sceneWidth = 320.0
        let tileWidth = 784.0
        for layerFactor in [0.15, 0.45, 1.0] {
            for distance in stride(from: 0.0, through: 2_000.0, by: 73.0) {
                let xs = WorldScroll.panoramaTileXs(
                    sceneWidth: sceneWidth, tileWidth: tileWidth, distance: distance, layerFactor: layerFactor
                )
                XCTAssertTrue(
                    coversFullRange(xs, tileWidth: tileWidth, sceneWidth: sceneWidth),
                    "layerFactor=\(layerFactor) distance=\(distance) 未完整覆蓋"
                )
            }
        }
    }

    func testPanoramaTileXsTilesAreContiguousWithoutGapOrOverlapDrift() {
        // 排序後相鄰 tile 間距應恰為 tileWidth（無縫接合，也不重疊到破壞平鋪規律）。
        let tileWidth = 784.0
        let xs = WorldScroll.panoramaTileXs(sceneWidth: 320, tileWidth: tileWidth, distance: 12345, layerFactor: 0.7)
        let sorted = xs.sorted()
        for i in 1..<sorted.count {
            XCTAssertEqual(sorted[i] - sorted[i - 1], tileWidth, accuracy: 0.0001)
        }
    }

    func testPanoramaTileXsZeroOrNegativeTileWidthReturnsEmpty() {
        XCTAssertEqual(WorldScroll.panoramaTileXs(sceneWidth: 320, tileWidth: 0, distance: 10, layerFactor: 1.0), [])
        XCTAssertEqual(WorldScroll.panoramaTileXs(sceneWidth: 320, tileWidth: -5, distance: 10, layerFactor: 1.0), [])
    }

    func testCharacterScreenXWithinExpectedLeftBand() {
        let sceneWidth = 320.0
        let x = WorldScroll.characterScreenX(sceneWidth: sceneWidth)

        // ADR-009：畫面左側約 20–25%
        XCTAssertGreaterThanOrEqual(x, sceneWidth * 0.15)
        XCTAssertLessThanOrEqual(x, sceneWidth * 0.30)
    }
}
