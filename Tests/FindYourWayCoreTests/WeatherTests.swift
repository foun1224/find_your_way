import XCTest
@testable import FindYourWayCore

/// `12_PHASE4_SPEC.md` §4 / `03_DESIGN_SYSTEM.md` §1.4：天氣純函式選擇與 overlay tint。
final class WeatherTests: XCTestCase {

    func testSameEpochAlwaysProducesSameWeather() {
        for index in [-100, -1, 0, 1, 42, 12345] {
            let a = Weather.kind(forEpochIndex: index)
            let b = Weather.kind(forEpochIndex: index)
            XCTAssertEqual(a, b, "同一 epoch index 應永遠得到同一天氣（確定性）")
        }
    }

    func testEpochIndexIsStableWithinPeriod() {
        let period = Weather.periodSeconds
        let base = Weather.epochIndex(unixSeconds: 10_000 * period)
        XCTAssertEqual(Weather.epochIndex(unixSeconds: 10_000 * period + 1), base)
        XCTAssertEqual(Weather.epochIndex(unixSeconds: 10_000 * period + period - 1), base)
        XCTAssertEqual(Weather.epochIndex(unixSeconds: 10_000 * period + period), base + 1)
    }

    func testDistributionSkewsTowardClear() {
        // 低喚醒基調：晴天應是多數（`12` §4 分布權重 60/25/15）。抽樣一大段區間統計比例。
        var counts: [WeatherKind: Int] = [.clear: 0, .overcast: 0, .rain: 0]
        let sampleCount = 10_000
        for i in 0..<sampleCount {
            let kind = Weather.kind(forEpochIndex: i)
            counts[kind, default: 0] += 1
        }
        let clearRatio = Double(counts[.clear] ?? 0) / Double(sampleCount)
        let rainRatio = Double(counts[.rain] ?? 0) / Double(sampleCount)
        XCTAssertGreaterThan(clearRatio, 0.5, "晴天應占多數")
        XCTAssertLessThan(rainRatio, 0.25, "雨天應是少數點綴，不壓過晴天")
    }

    func testClearHasNoOverlayTint() {
        XCTAssertNil(Weather.overlayTint(for: .clear))
    }

    func testOvercastSoftensWithLowAlpha() {
        let tint = Weather.overlayTint(for: .overcast)
        XCTAssertNotNil(tint)
        // 柔化不施壓：alpha 保持克制，不遮蔽像素美術辨識度。
        XCTAssertLessThan(tint!.alpha, 0.4)
    }

    func testRainIsCoolAndBlueLeaning() {
        let tint = Weather.overlayTint(for: .rain)
        XCTAssertNotNil(tint)
        XCTAssertGreaterThan(tint!.blue, tint!.red, "雨天應冷偏藍")
        XCTAssertLessThan(tint!.alpha, 0.4, "天氣一律柔化，不製造戲劇性壓力")
    }
}
