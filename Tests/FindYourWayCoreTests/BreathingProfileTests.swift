import XCTest
@testable import FindYourWayCore

/// `docs/22_COMPANIONSHIP_DESIGN.md` §Stage P3（rest-breath co-regulation）：
/// 覆蓋「resting 狀態 → 呼吸週期/振幅」這段純選擇邏輯，以及低喚醒守則（`02` §6）
/// 要求的「休息呼吸不能變成明顯脈動」數值區間。
final class BreathingProfileTests: XCTestCase {

    func testWalkingUsesWalkPeriodAndAmplitude() {
        XCTAssertEqual(
            BreathingProfile.periodSeconds(isResting: false),
            BreathingProfile.walkPeriodSeconds,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            BreathingProfile.scaleAmplitude(isResting: false),
            BreathingProfile.walkScaleAmplitude,
            accuracy: 0.0001
        )
    }

    func testRestingUsesRestPeriodAndAmplitude() {
        XCTAssertEqual(
            BreathingProfile.periodSeconds(isResting: true),
            BreathingProfile.restPeriodSeconds,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            BreathingProfile.scaleAmplitude(isResting: true),
            BreathingProfile.restScaleAmplitude,
            accuracy: 0.0001
        )
    }

    /// 休息呼吸要比走路呼吸慢得多（~10s vs 3.6s），才有「靜下來」的感覺，
    /// 且落在 coherent breathing（~6 次/分 ≈ 10 秒一次呼吸）的常見範圍。
    func testRestPeriodIsSlowerThanWalkAndNearCoherentBreathingRange() {
        XCTAssertGreaterThan(BreathingProfile.restPeriodSeconds, BreathingProfile.walkPeriodSeconds)
        XCTAssertGreaterThanOrEqual(BreathingProfile.restPeriodSeconds, 8.0)
        XCTAssertLessThanOrEqual(BreathingProfile.restPeriodSeconds, 12.0)
    }

    /// 低喚醒守則（`02` §6）：休息呼吸振幅可略增（讓慢週期下仍可察覺「活著」），
    /// 但必須落在文件建議的 0.018–0.022 區間，不能變成明顯脈動。
    func testRestAmplitudeIsGentlyLargerThanWalkButStillRestrained() {
        XCTAssertGreaterThan(BreathingProfile.restScaleAmplitude, BreathingProfile.walkScaleAmplitude)
        XCTAssertGreaterThanOrEqual(BreathingProfile.restScaleAmplitude, 0.018)
        XCTAssertLessThanOrEqual(BreathingProfile.restScaleAmplitude, 0.022)
    }

    /// 走路呼吸振幅維持現行克制值（`13_PSYCH_AUDIT.md` P1），P3 不應動到走路的呼吸。
    func testWalkAmplitudeUnchanged() {
        XCTAssertEqual(BreathingProfile.walkScaleAmplitude, 0.012, accuracy: 0.0001)
        XCTAssertEqual(BreathingProfile.walkPeriodSeconds, 3.6, accuracy: 0.0001)
    }
}
