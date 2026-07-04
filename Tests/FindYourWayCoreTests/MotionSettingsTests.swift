import XCTest
@testable import FindYourWayCore

final class MotionSettingsTests: XCTestCase {

    func testFollowsSystemWhenUserHasNotOverridden_systemOn() {
        XCTAssertTrue(MotionSettings.effectiveReduceMotion(userOverride: nil, systemPref: true))
    }

    func testFollowsSystemWhenUserHasNotOverridden_systemOff() {
        XCTAssertFalse(MotionSettings.effectiveReduceMotion(userOverride: nil, systemPref: false))
    }

    func testUserOverrideFalseWinsOverSystemOn() {
        XCTAssertFalse(MotionSettings.effectiveReduceMotion(userOverride: false, systemPref: true))
    }

    func testUserOverrideTrueWinsOverSystemOff() {
        XCTAssertTrue(MotionSettings.effectiveReduceMotion(userOverride: true, systemPref: false))
    }
}
