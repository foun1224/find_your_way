import XCTest
@testable import FindYourWayCore

/// `12_PHASE4_SPEC.md` §3 / `03_DESIGN_SYSTEM.md` §1.4：晝夜色調純函式映射。
final class DayNightCycleTests: XCTestCase {

    private func hours(_ h: Double) -> Double { h * 3600 }

    func testNightIsNotPureBlackAndHasNonZeroAlpha() {
        let midnight = DayNightCycle.tint(forSecondsIntoDay: hours(2))
        // 夜間「不純黑」：色相須帶藍紫、且 overlay 本身不是全不透明遮蓋（保留可辨識度）。
        XCTAssertGreaterThan(midnight.blue, midnight.red)
        XCTAssertLessThan(midnight.alpha, 0.5)
        XCTAssertGreaterThan(midnight.alpha, 0.0)
    }

    func testDayIsNearNeutralBaseline() {
        let noon = DayNightCycle.tint(forSecondsIntoDay: hours(12))
        // 白日＝近乎無 tint 的基準：alpha 應趨近 0（不明顯染色）。
        XCTAssertLessThan(noon.alpha, 0.05)
    }

    func testDawnIsWarm() {
        let dawn = DayNightCycle.tint(forSecondsIntoDay: hours(6))
        XCTAssertGreaterThan(dawn.red, dawn.blue, "黎明應偏暖（紅通道 > 藍通道）")
    }

    func testGoldenHourIsWarmestPeak() {
        let golden = DayNightCycle.tint(forSecondsIntoDay: hours(18))
        let noon = DayNightCycle.tint(forSecondsIntoDay: hours(12))
        XCTAssertGreaterThan(golden.alpha, noon.alpha, "黃金時刻應比白日基準更濃烈")
        XCTAssertGreaterThan(golden.red, golden.blue, "黃金時刻應是暖色調")
    }

    func testDuskTransitionsTowardCool() {
        let dusk = DayNightCycle.tint(forSecondsIntoDay: hours(20))
        XCTAssertGreaterThanOrEqual(dusk.blue, dusk.red, "黃昏應轉冷（藍 >= 紅）")
    }

    func testNoJumpAcrossAdjacentMinutes() {
        // 分鐘級平滑漸變：任一相鄰兩分鐘之間的色差都應很小（不跳變）。
        var previous = DayNightCycle.tint(forSecondsIntoDay: 0)
        var maxDelta: Double = 0
        var t: Double = 60
        while t <= DayNightCycle.secondsPerDay {
            let current = DayNightCycle.tint(forSecondsIntoDay: t)
            let delta = abs(current.red - previous.red)
                + abs(current.green - previous.green)
                + abs(current.blue - previous.blue)
                + abs(current.alpha - previous.alpha)
            maxDelta = max(maxDelta, delta)
            previous = current
            t += 60
        }
        XCTAssertLessThan(maxDelta, 0.03, "相鄰一分鐘的色差應極小（最快的過渡也遠低於「跳變」量級），確保無跳變")
    }

    func test24HourWrapIsContinuous() {
        // 環狀 wrap：23:59:30 附近應平滑接回 00:00:30 附近，而非在跨日邊界跳變。
        let justBeforeMidnight = DayNightCycle.tint(forSecondsIntoDay: DayNightCycle.secondsPerDay - 30)
        let justAfterMidnight = DayNightCycle.tint(forSecondsIntoDay: 30)
        let delta = abs(justBeforeMidnight.red - justAfterMidnight.red)
            + abs(justBeforeMidnight.green - justAfterMidnight.green)
            + abs(justBeforeMidnight.blue - justAfterMidnight.blue)
            + abs(justBeforeMidnight.alpha - justAfterMidnight.alpha)
        XCTAssertLessThan(delta, 0.01)
    }

    func testNegativeAndOverflowSecondsWrapCorrectly() {
        let normal = DayNightCycle.tint(forSecondsIntoDay: hours(6))
        let overflowed = DayNightCycle.tint(forSecondsIntoDay: hours(6) + DayNightCycle.secondsPerDay * 3)
        let negative = DayNightCycle.tint(forSecondsIntoDay: hours(6) - DayNightCycle.secondsPerDay)
        XCTAssertEqual(normal.red, overflowed.red, accuracy: 0.0001)
        XCTAssertEqual(normal.red, negative.red, accuracy: 0.0001)
    }
}
