import XCTest
@testable import FindYourWayCore

/// `16_STAGE_A_SPEC.md` §1 / §5：季節純函式邊界、循環、插值連續性。
final class SeasonTests: XCTestCase {

    func testDistanceZeroIsSpring() {
        XCTAssertEqual(Season.at(distance: 0), .spring)
    }

    func testFourSeasonBoundaries() {
        let length = Season.seasonLength
        XCTAssertEqual(Season.at(distance: 0), .spring)
        XCTAssertEqual(Season.at(distance: length - 1), .spring)
        XCTAssertEqual(Season.at(distance: length), .summer)
        XCTAssertEqual(Season.at(distance: length * 2), .autumn)
        XCTAssertEqual(Season.at(distance: length * 3), .winter)
    }

    func testCyclesBackToSpringAfterOneYear() {
        let length = Season.seasonLength
        XCTAssertEqual(Season.at(distance: length * 4), .spring)
        XCTAssertEqual(Season.at(distance: length * 4 + 10), .spring)
        XCTAssertEqual(Season.at(distance: length * 5), .summer)
    }

    func testNegativeDistanceWrapsCorrectly() {
        let length = Season.seasonLength
        // -1 里程應落在「前一個循環」的最後一季：冬。
        XCTAssertEqual(Season.at(distance: -1), .winter)
        XCTAssertEqual(Season.at(distance: -length), .winter)
        XCTAssertEqual(Season.at(distance: -length - 1), .autumn)
    }

    func testSeasonMidpointColorMatchesAuthoredTint() {
        let length = Season.seasonLength
        // 季節中點（遠離交界模糊帶）應回傳該季 authored 純色，無插值污染。
        let springMid = Season.tint(atDistance: length * 0.1)
        let springColor = Palette.parseHex("#9FD68A")!
        XCTAssertEqual(springMid.red, springColor.red, accuracy: 0.0001)
        XCTAssertEqual(springMid.green, springColor.green, accuracy: 0.0001)
        XCTAssertEqual(springMid.blue, springColor.blue, accuracy: 0.0001)
        XCTAssertEqual(springMid.alpha, 0.14, accuracy: 0.0001)

        let summerMid = Season.tint(atDistance: length + length * 0.1)
        let summerColor = Palette.parseHex("#F2CE73")!
        XCTAssertEqual(summerMid.red, summerColor.red, accuracy: 0.0001)
        XCTAssertEqual(summerMid.alpha, 0.10, accuracy: 0.0001)

        let autumnMid = Season.tint(atDistance: length * 2 + length * 0.1)
        XCTAssertEqual(autumnMid.alpha, 0.18, accuracy: 0.0001)

        let winterMid = Season.tint(atDistance: length * 3 + length * 0.1)
        XCTAssertEqual(winterMid.alpha, 0.20, accuracy: 0.0001)
    }

    func testTintInterpolatesSmoothlyAcrossBoundaryWithNoJump() {
        // 交界附近逐步取樣，相鄰兩點色差應很小（無跳變），同 DayNightCycle 範式。
        let length = Season.seasonLength
        var previous = Season.tint(atDistance: length - length * 0.3)
        var maxDelta: Double = 0
        var d = length - length * 0.3
        let step = length * 0.001
        while d <= length + step {
            let current = Season.tint(atDistance: d)
            let delta = abs(current.red - previous.red)
                + abs(current.green - previous.green)
                + abs(current.blue - previous.blue)
                + abs(current.alpha - previous.alpha)
            maxDelta = max(maxDelta, delta)
            previous = current
            d += step
        }
        XCTAssertLessThan(maxDelta, 0.01, "季節交界附近的 tint 應平滑插值，無跳變")
    }

    func testTintAtExactBoundaryEqualsNextSeasonPureColor() {
        // 交界瞬間（u=1）應完全等於下一季純色（插值終點）。
        let length = Season.seasonLength
        let atBoundary = Season.tint(atDistance: length)
        let summerColor = Palette.parseHex("#F2CE73")!
        XCTAssertEqual(atBoundary.red, summerColor.red, accuracy: 0.0001)
        XCTAssertEqual(atBoundary.alpha, 0.10, accuracy: 0.0001)
    }

    func testWinterOverlayAlphaWithinReadableButGentleRange() {
        // 冬天 alpha 最高但仍克制（`16` §1.2：清冷但非死寂）。
        let winterMid = Season.tint(atDistance: Season.seasonLength * 3 + 10)
        XCTAssertGreaterThan(winterMid.alpha, 0.0)
        XCTAssertLessThan(winterMid.alpha, 0.3)
    }
}
