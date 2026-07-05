import XCTest
@testable import FindYourWayCore

final class PreferencesStoreTests: XCTestCase {

    /// 每個測試使用獨立 suite name 建 `UserDefaults`，避免污染 `.standard` 且互不干擾。
    private func makeIsolatedDefaults(_ name: String = #function) -> UserDefaults {
        let suiteName = "com.findyourway.tests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    func testDefaultPreferencesWhenNothingWritten() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        let prefs = store.load()

        XCTAssertNil(prefs.reduceMotionOverride)
        XCTAssertEqual(prefs.volume, 1.0, accuracy: 0.0001)
    }

    func testWriteReadRoundTripReduceMotionTrue() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setReduceMotionOverride(true)

        XCTAssertEqual(store.load().reduceMotionOverride, true)
    }

    func testWriteReadRoundTripReduceMotionFalse() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setReduceMotionOverride(false)

        XCTAssertEqual(store.load().reduceMotionOverride, false)
    }

    func testClearingOverrideReturnsToNilFollowSystem() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setReduceMotionOverride(true)
        store.setReduceMotionOverride(nil)

        XCTAssertNil(store.load().reduceMotionOverride)
    }

    func testInjectedDefaultsDoNotLeakIntoStandard() {
        let isolated = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: isolated)
        store.setReduceMotionOverride(true)

        XCTAssertNil(UserDefaults.standard.object(forKey: PreferencesKey.reduceMotionOverride))
    }

    func testVolumeRoundTrip() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setVolume(0.5)

        XCTAssertEqual(store.load().volume, 0.5, accuracy: 0.0001)
    }

    func testWindowOriginNilByDefault() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        XCTAssertNil(store.load().windowOrigin)
    }

    func testWindowOriginRoundTrip() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setWindowOrigin(CGPoint(x: 123.5, y: 67.25))

        let loaded = store.load().windowOrigin
        XCTAssertEqual(Double(loaded?.x ?? -1), 123.5, accuracy: 0.0001)
        XCTAssertEqual(Double(loaded?.y ?? -1), 67.25, accuracy: 0.0001)
    }

    func testClearingWindowOriginReturnsToNil() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setWindowOrigin(CGPoint(x: 10, y: 20))
        store.setWindowOrigin(nil)

        XCTAssertNil(store.load().windowOrigin)
    }

    // MARK: - 拉場景大小：視窗尺寸記憶（2026-07-05）

    func testWindowSizeNilByDefault() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        XCTAssertNil(store.load().windowSize)
    }

    func testWindowSizeRoundTrip() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setWindowSize(CGSize(width: 480.5, height: 270.25))

        let loaded = store.load().windowSize
        XCTAssertEqual(Double(loaded?.width ?? -1), 480.5, accuracy: 0.0001)
        XCTAssertEqual(Double(loaded?.height ?? -1), 270.25, accuracy: 0.0001)
    }

    func testClearingWindowSizeReturnsToNil() {
        let store = PreferencesStore(defaults: makeIsolatedDefaults())
        store.setWindowSize(CGSize(width: 400, height: 300))
        store.setWindowSize(nil)

        XCTAssertNil(store.load().windowSize)
    }

    func testWindowOriginDoesNotLeakIntoStandard() {
        let isolated = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: isolated)
        store.setWindowOrigin(CGPoint(x: 10, y: 20))

        XCTAssertNil(UserDefaults.standard.object(forKey: PreferencesKey.windowOriginX))
    }

    func testTwoStoresWithDifferentDefaultsAreIsolated() {
        let storeA = PreferencesStore(defaults: makeIsolatedDefaults("A"))
        let storeB = PreferencesStore(defaults: makeIsolatedDefaults("B"))

        storeA.setReduceMotionOverride(true)

        XCTAssertEqual(storeA.load().reduceMotionOverride, true)
        XCTAssertNil(storeB.load().reduceMotionOverride)
    }
}
