import XCTest
@testable import FindYourWayCore

final class SaveStoreTests: XCTestCase {

    private var tmpRoot: URL!

    override func setUp() {
        super.setUp()
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FindYourWayTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpRoot)
        tmpRoot = nil
        super.tearDown()
    }

    private func makeStore() -> SaveStore {
        SaveStore(paths: SavePaths(rootDirectory: tmpRoot))
    }

    func testRoundTripSaveThenLoadReturnsEqualState() {
        let store = makeStore()
        let state = GameState(distance: 777, landmarksPassed: ["windy_pass"], lastActiveTimestamp: 1_000, growth: 3)

        XCTAssertTrue(store.save(state))
        let loaded = store.load()

        XCTAssertEqual(loaded, state)
    }

    func testAtomicWriteProducesFullyDecodableFile() {
        let store = makeStore()
        let state = GameState(distance: 10)
        store.save(state)

        let paths = SavePaths(rootDirectory: tmpRoot)
        let data = try? Data(contentsOf: paths.saveFileURL)
        XCTAssertNotNil(data)
        XCTAssertNoThrow(try JSONDecoder().decode(GameState.self, from: data!))
    }

    func testBadSaveFileFallsBackToValidBackup() throws {
        let paths = SavePaths(rootDirectory: tmpRoot)
        try paths.ensureDirectoryExists()

        let goodState = GameState(distance: 55)
        let goodData = try JSONEncoder().encode(goodState)
        try goodData.write(to: paths.backupFileURL)
        try "not valid json {{{".data(using: .utf8)!.write(to: paths.saveFileURL)

        let store = makeStore()
        let loaded = store.load()

        XCTAssertEqual(loaded, goodState)
    }

    func testBothFilesBadOrMissingReturnsNil() throws {
        let store = makeStore()
        // 兩者皆不存在
        XCTAssertNil(store.load())

        let paths = SavePaths(rootDirectory: tmpRoot)
        try paths.ensureDirectoryExists()
        try "broken".data(using: .utf8)!.write(to: paths.saveFileURL)
        try "also broken".data(using: .utf8)!.write(to: paths.backupFileURL)

        XCTAssertNil(store.load())
    }

    func testSavingAgainBacksUpPreviousVersion() {
        let store = makeStore()
        let firstState = GameState(distance: 1)
        let secondState = GameState(distance: 2)

        store.save(firstState)
        store.save(secondState)

        let paths = SavePaths(rootDirectory: tmpRoot)
        let backupData = try? Data(contentsOf: paths.backupFileURL)
        XCTAssertNotNil(backupData)
        let backupState = try? JSONDecoder().decode(GameState.self, from: backupData!)
        XCTAssertEqual(backupState, firstState)
    }

    func testFutureSchemaVersionIsTreatedAsInvalidAndFallsBackSafely() throws {
        let paths = SavePaths(rootDirectory: tmpRoot)
        try paths.ensureDirectoryExists()

        let futureState = GameState(schemaVersion: SaveSchema.currentVersion + 1, distance: 999)
        let futureData = try JSONEncoder().encode(futureState)
        try futureData.write(to: paths.saveFileURL)

        let store = makeStore()
        // 沒有 .bak 可回退 → 安全地回傳 nil，不 crash、不誤讀未來版本。
        XCTAssertNil(store.load())
    }
}
