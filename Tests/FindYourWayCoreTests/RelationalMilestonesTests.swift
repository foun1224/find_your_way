import XCTest
@testable import FindYourWayCore

/// `docs/22_COMPANIONSHIP_DESIGN.md` §5b：關係性時刻確定性選句、稀疏槽距、不緊鄰重複、
/// 不依賴牆鐘、authored 文案一字照用。
final class RelationalMilestonesTests: XCTestCase {

    func testSixAuthoredLinesOneWordExact() {
        // 一字照用 `22` §5b 六句。
        XCTAssertEqual(RelationalMilestones.lines, [
            "不知不覺，我們一起走了好長一段路。",
            "又一起走過了一個季節。",
            "一起看過的日落，已經數不清了。",
            "路還長，還好有你在。",
            "有些風景，是因為有人一起看著，才留得住。",
            "你在的時候，連沉默都覺得踏實。"
        ])
    }

    func testSpacingIsSparserThanEncounterDeck() {
        // 關係性時刻必須明顯稀疏於相遇卡（`22` §5b：建議每 ~90000 里程，比相遇卡 28800 稀疏很多）。
        XCTAssertEqual(RelationalMilestones.relationalSpacing, 90_000)
        XCTAssertGreaterThan(RelationalMilestones.relationalSpacing, EncounterDeck.cardSpacing * 3)
    }

    func testSlotIndexMatchesSpec() {
        let spacing = RelationalMilestones.relationalSpacing
        XCTAssertEqual(RelationalMilestones.slotIndex(atDistance: 0), 0)
        XCTAssertEqual(RelationalMilestones.slotIndex(atDistance: spacing - 1), 0)
        XCTAssertEqual(RelationalMilestones.slotIndex(atDistance: spacing), 1)
        XCTAssertEqual(RelationalMilestones.slotIndex(atDistance: spacing * 10), 10)
    }

    func testSameSlotAlwaysProducesSameLine() {
        for slot in [0, 1, 2, 5, 42, 1000] {
            let a = RelationalMilestones.line(atSlot: slot)
            let b = RelationalMilestones.line(atSlot: slot)
            XCTAssertEqual(a, b, "同一 slotIndex 應永遠選到同一句（確定性）")
        }
    }

    func testDoesNotDependOnWallClock() {
        // 純函式：簽章完全沒有「現在時間」的輸入，重複呼叫同一 slot 不變。
        let results = (0..<5).map { _ in RelationalMilestones.line(atSlot: 7) }
        XCTAssertTrue(results.allSatisfy { $0 == results[0] })
    }

    func testEverySelectedLineIsAuthored() {
        for slot in 0..<200 {
            let line = RelationalMilestones.line(atSlot: slot)
            XCTAssertTrue(RelationalMilestones.lines.contains(line), "slot \(slot) 選出的句子必須是 authored 清單中的一句")
        }
    }

    func testNoImmediateAdjacentRepeat() {
        var previous: String?
        for slot in 0..<300 {
            let line = RelationalMilestones.line(atSlot: slot)
            if let previous {
                XCTAssertNotEqual(line, previous, "slot \(slot) 不應與上一槽選到同一句")
            }
            previous = line
        }
    }

    func testAllSixLinesEventuallyAppear() {
        // 掃過足夠多槽，六句 authored 文案都應該有機會出現（確保沒有句子被鎖死永遠選不到）。
        var seen = Set<String>()
        for slot in 0..<200 {
            seen.insert(RelationalMilestones.line(atSlot: slot))
        }
        XCTAssertEqual(seen, Set(RelationalMilestones.lines))
    }
}
