import XCTest
@testable import FindYourWayCore

final class StatusCardTests: XCTestCase {

    func testShowsMostRecentLandmarkNameNotRawDistance() {
        let state = GameState(distance: 300_000, landmarksPassed: ["windy_pass", "nameless_bend", "old_bridge"])
        let lines = StatusCardText.lines(for: state)

        XCTAssertTrue(lines.contains("已路過：一座舊石橋"))
        // 不得含裸數字距離。
        XCTAssertFalse(lines.joined().contains("300000"))
    }

    func testNoLandmarksPassedShowsGlanceablePlaceholder() {
        let state = GameState(distance: 0, landmarksPassed: [])
        let lines = StatusCardText.lines(for: state)

        XCTAssertTrue(lines.contains(StatusCardText.noLandmarksPassedText))
    }

    func testCompanionNotJoinedHidesCompanionLine() {
        let state = GameState(distance: 100, companionJoined: false)
        let lines = StatusCardText.lines(for: state)

        XCTAssertFalse(lines.contains(StatusCardText.companionJoinedText))
    }

    func testCompanionJoinedShowsCompanionLine() {
        let state = GameState(distance: Companion.meetDistance, companionJoined: true)
        let lines = StatusCardText.lines(for: state)

        XCTAssertTrue(lines.contains(StatusCardText.companionJoinedText))
    }

    func testChapterNameMapsFromGrowthStage() {
        let state = GameState(distance: 432_000)
        let lines = StatusCardText.lines(for: state)

        XCTAssertTrue(lines.contains(GrowthStage.chapterName(forDistance: 432_000)))
        XCTAssertTrue(lines.contains("第三章 · 遠方的雪"))
    }

    func testLinesCappedAtThreeWhenCompanionJoined() {
        let state = GameState(distance: Companion.meetDistance, landmarksPassed: ["old_bridge"], companionJoined: true)
        let lines = StatusCardText.lines(for: state)

        XCTAssertEqual(lines.count, 3)
    }

    func testLinesCappedAtTwoWhenCompanionNotJoined() {
        let state = GameState(distance: 100, landmarksPassed: ["windy_pass"], companionJoined: false)
        let lines = StatusCardText.lines(for: state)

        XCTAssertEqual(lines.count, 2)
    }
}
