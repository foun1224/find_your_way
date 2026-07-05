import XCTest
@testable import FindYourWayCore

/// `docs/22_COMPANIONSHIP_DESIGN.md` §5b：深夜陪伴的真實時刻判定（含跨午夜 wrap）、
/// 破曉窗口判定、長冷卻節流、確定性選句、authored 文案一字照用、絕不含健康說教語氣。
final class LateNightPresenceTests: XCTestCase {

    // MARK: - 窗口判定

    func testLateNightWindowIncludesBoundaryStart() {
        XCTAssertTrue(LateNightPresence.isLateNight(secondsIntoDay: 23 * 3600)) // 23:00 含
    }

    func testLateNightWindowExcludesBoundaryEnd() {
        XCTAssertFalse(LateNightPresence.isLateNight(secondsIntoDay: 4 * 3600)) // 04:00 不含
    }

    func testLateNightWindowWrapsAcrossMidnight() {
        XCTAssertTrue(LateNightPresence.isLateNight(secondsIntoDay: 23.5 * 3600)) // 23:30
        XCTAssertTrue(LateNightPresence.isLateNight(secondsIntoDay: 0)) // 00:00
        XCTAssertTrue(LateNightPresence.isLateNight(secondsIntoDay: 2 * 3600)) // 02:00
        XCTAssertTrue(LateNightPresence.isLateNight(secondsIntoDay: 3.9 * 3600)) // 03:54
    }

    func testDaytimeIsNeverLateNight() {
        for hour in [4.5, 8, 12, 18, 20, 22.9] {
            XCTAssertFalse(LateNightPresence.isLateNight(secondsIntoDay: hour * 3600), "\(hour) 時不應判定為深夜")
        }
    }

    func testDawnWindowBoundaries() {
        XCTAssertTrue(LateNightPresence.isDawn(secondsIntoDay: 5 * 3600)) // 05:00 含
        XCTAssertFalse(LateNightPresence.isDawn(secondsIntoDay: 7 * 3600)) // 07:00 不含
        XCTAssertTrue(LateNightPresence.isDawn(secondsIntoDay: 6 * 3600))
    }

    func testDawnAndLateNightWindowsDoNotOverlap() {
        for hour in stride(from: 0.0, to: 24.0, by: 0.25) {
            let seconds = hour * 3600
            let bothTrue = LateNightPresence.isLateNight(secondsIntoDay: seconds) && LateNightPresence.isDawn(secondsIntoDay: seconds)
            XCTAssertFalse(bothTrue, "\(hour) 時不應同時判定為深夜與破曉")
        }
    }

    // MARK: - 冷卻節流

    func testCanTriggerRespectsCooldown() {
        XCTAssertFalse(LateNightPresence.canTrigger(now: 100, lastTriggerTime: 90, cooldown: 60))
        XCTAssertTrue(LateNightPresence.canTrigger(now: 200, lastTriggerTime: 90, cooldown: 60))
    }

    func testCanTriggerTrueWhenNeverTriggeredBefore() {
        XCTAssertTrue(LateNightPresence.canTrigger(now: 0, lastTriggerTime: -.infinity, cooldown: LateNightPresence.lateNightCooldownSeconds))
    }

    func testCooldownsAreSparse() {
        // `22` §5b「稀疏，長冷卻，建議每次深夜時段內間隔 ≥ 30~45 分」。
        XCTAssertGreaterThanOrEqual(LateNightPresence.lateNightCooldownSeconds, 30 * 60)
        XCTAssertLessThanOrEqual(LateNightPresence.lateNightCooldownSeconds, 45 * 60)
        // 破曉冷卻應比一整夜還長，確保同一晚最多播一次（罕見）。
        XCTAssertGreaterThan(LateNightPresence.dawnCooldownSeconds, 8 * 3600)
    }

    // MARK: - Authored 文案（一字照用）

    func testFourLateNightLinesOneWordExact() {
        XCTAssertEqual(LateNightPresence.lateNightLines, [
            "夜深了。你還在，我也還在。",
            "夜裡很安靜，我陪你走一段。",
            "燈還亮著。不急，我在。",
            "這麼晚了還在忙。我不吵你，就在這。"
        ])
    }

    func testDawnLineOneWordExact() {
        XCTAssertEqual(LateNightPresence.dawnLine, "天要亮了。這一夜，有你，不孤單。")
    }

    func testNoLateNightLineMentionsSleepOrHealth() {
        // `22` §6 不做：任何「該去睡/該休息/健康」語氣皆是侵入，鐵律嚴禁。
        let forbiddenWords = ["睡", "休息", "健康", "早點", "該去"]
        for line in LateNightPresence.lateNightLines + [LateNightPresence.dawnLine] {
            for word in forbiddenWords {
                XCTAssertFalse(line.contains(word), "\"\(line)\" 不應包含健康說教字眼 \"\(word)\"")
            }
        }
    }

    // MARK: - 確定性選句

    func testSameSlotAlwaysProducesSameLateNightLine() {
        for slot in [0, 1, 2, 5, 42, 1000] {
            let a = LateNightPresence.lateNightLine(atSlot: slot)
            let b = LateNightPresence.lateNightLine(atSlot: slot)
            XCTAssertEqual(a, b, "同一 slotIndex 應永遠選到同一句（確定性）")
        }
    }

    func testLateNightSlotIndexIsDeterministicFunctionOfNow() {
        let cooldown = LateNightPresence.lateNightCooldownSeconds
        XCTAssertEqual(LateNightPresence.lateNightSlotIndex(atUnixSeconds: 0), 0)
        XCTAssertEqual(LateNightPresence.lateNightSlotIndex(atUnixSeconds: cooldown - 1), 0)
        XCTAssertEqual(LateNightPresence.lateNightSlotIndex(atUnixSeconds: cooldown), 1)
    }

    func testNoImmediateAdjacentRepeatForLateNightLines() {
        var previous: String?
        for slot in 0..<300 {
            let line = LateNightPresence.lateNightLine(atSlot: slot)
            if let previous {
                XCTAssertNotEqual(line, previous, "slot \(slot) 不應與上一槽選到同一句")
            }
            previous = line
        }
    }

    func testAllFourLateNightLinesEventuallyAppear() {
        var seen = Set<String>()
        for slot in 0..<200 {
            seen.insert(LateNightPresence.lateNightLine(atSlot: slot))
        }
        XCTAssertEqual(seen, Set(LateNightPresence.lateNightLines))
    }
}
