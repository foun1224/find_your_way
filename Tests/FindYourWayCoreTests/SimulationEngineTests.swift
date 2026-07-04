import XCTest
@testable import FindYourWayCore

final class SimulationEngineTests: XCTestCase {

    let rules = SimulationRules.default

    func testAdvanceIncreasesDistanceByRulesFormula() {
        let state = GameState(distance: 100)
        let (newState, _, _, _) = SimulationEngine.advance(state, bySeconds: 10, rules: rules)
        XCTAssertEqual(newState.distance, 100 + rules.distanceGained(overSeconds: 10), accuracy: 0.0001)
    }

    func testZeroDtDoesNotChangeState() {
        let state = GameState(distance: 42, landmarksPassed: ["x"], growth: 5)
        let (newState, crossed, _, _) = SimulationEngine.advance(state, bySeconds: 0, rules: rules)
        XCTAssertEqual(newState, state)
        XCTAssertTrue(crossed.isEmpty)
    }

    func testNegativeDtDoesNotChangeState() {
        let state = GameState(distance: 42)
        let (newState, crossed, _, _) = SimulationEngine.advance(state, bySeconds: -5, rules: rules)
        XCTAssertEqual(newState, state)
        XCTAssertTrue(crossed.isEmpty)
    }

    func testCrossingLandmarkAddsItOnceInOrder() {
        let firstLandmark = Landmark.all[0]
        // 走到剛好越過第一個地標所需的秒數。
        let secondsToCross = (firstLandmark.distance + 1) / rules.speed
        let state = GameState(distance: 0)

        let (newState, crossed, _, _) = SimulationEngine.advance(state, bySeconds: secondsToCross, rules: rules)

        XCTAssertEqual(crossed.map(\.id), [firstLandmark.id])
        XCTAssertEqual(newState.landmarksPassed, [firstLandmark.id])
    }

    func testRepeatedlyPassingSameLandmarkDoesNotDuplicate() {
        let firstLandmark = Landmark.all[0]
        var state = GameState(distance: firstLandmark.distance + 10)
        state.landmarksPassed = [firstLandmark.id]

        let (newState, crossed, _, _) = SimulationEngine.advance(state, bySeconds: 1, rules: rules)

        XCTAssertTrue(crossed.isEmpty)
        XCTAssertEqual(newState.landmarksPassed, [firstLandmark.id])
    }

    func testLandmarksPassedStaysOrderedAcrossMultipleCrossings() {
        let first = Landmark.all[0]
        let second = Landmark.all[1]
        let secondsToCrossBoth = (second.distance + 1) / rules.speed
        let state = GameState(distance: 0)

        let (newState, crossed, _, _) = SimulationEngine.advance(state, bySeconds: secondsToCrossBoth, rules: rules)

        XCTAssertEqual(crossed.map(\.id), [first.id, second.id])
        XCTAssertEqual(newState.landmarksPassed, [first.id, second.id])
    }

    func testMultipleSmallDtStepsEqualsOneLargeDtStep() {
        let state = GameState(distance: 0)
        var accumulated = state
        for _ in 0..<10 {
            let (next, _, _, _) = SimulationEngine.advance(accumulated, bySeconds: 100, rules: rules)
            accumulated = next
        }
        let (single, _, _, _) = SimulationEngine.advance(state, bySeconds: 1000, rules: rules)
        XCTAssertEqual(accumulated.distance, single.distance, accuracy: 0.0001)
    }

    func testDistanceAndLandmarksAreMonotonicNonDecreasing() {
        var state = GameState(distance: 0)
        var previousDistance = state.distance
        var previousLandmarkCount = state.landmarksPassed.count

        for _ in 0..<50 {
            let (next, _, _, _) = SimulationEngine.advance(state, bySeconds: 500, rules: rules)
            XCTAssertGreaterThanOrEqual(next.distance, previousDistance)
            XCTAssertGreaterThanOrEqual(next.landmarksPassed.count, previousLandmarkCount)
            previousDistance = next.distance
            previousLandmarkCount = next.landmarksPassed.count
            state = next
        }
    }

    func testAdvanceDoesNotUpdateTimestamp() {
        let state = GameState(distance: 0, lastActiveTimestamp: 12345)
        let (newState, _, _, _) = SimulationEngine.advance(state, bySeconds: 100, rules: rules)
        XCTAssertEqual(newState.lastActiveTimestamp, 12345)
    }
}
