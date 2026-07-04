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

    /// 誠實標版：save 後寫進磁碟的 JSON `schemaVersion` 應為當前版本（2），
    /// 即使傳入的 state 帶舊版號。
    func testSaveStampsCurrentSchemaVersionOnDisk() throws {
        let store = makeStore()
        let oldVersionedState = GameState(schemaVersion: 1, distance: 42)

        XCTAssertTrue(store.save(oldVersionedState))

        let paths = SavePaths(rootDirectory: tmpRoot)
        let data = try Data(contentsOf: paths.saveFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, SaveSchema.currentVersion)
        XCTAssertEqual(SaveSchema.currentVersion, 2)
    }

    /// v1 舊檔（無新欄位）load → re-save → 變成 schemaVersion 2，舊資料不丟。
    func testV1SaveFileLoadReSaveBecomesV2WithoutLosingOldData() throws {
        let paths = SavePaths(rootDirectory: tmpRoot)
        try paths.ensureDirectoryExists()

        // 手寫一個 v1 檔：schemaVersion 1、無 eventsEncountered/companionJoined。
        let v1Json = """
        {
            "schemaVersion": 1,
            "distance": 12345.6,
            "landmarksPassed": ["windy_pass", "nameless_bend"],
            "lastActiveTimestamp": 1000,
            "growth": 78.9
        }
        """.data(using: .utf8)!
        try v1Json.write(to: paths.saveFileURL)

        let store = makeStore()
        let loaded = try XCTUnwrap(store.load())
        // 向後相容：v1 檔載入時新欄位給安全預設。
        XCTAssertEqual(loaded.eventsEncountered, [])
        XCTAssertFalse(loaded.companionJoined)

        XCTAssertTrue(store.save(loaded))

        // re-save 後磁碟上為 v2，舊資料原樣保留。
        let reloadedData = try Data(contentsOf: paths.saveFileURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: reloadedData) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 2)
        XCTAssertEqual(json["distance"] as? Double, 12345.6)
        XCTAssertEqual(json["growth"] as? Double, 78.9)
        XCTAssertEqual(json["landmarksPassed"] as? [String], ["windy_pass", "nameless_bend"])

        let reloaded = try XCTUnwrap(store.load())
        XCTAssertEqual(reloaded.schemaVersion, 2)
        XCTAssertEqual(reloaded.distance, 12345.6, accuracy: 0.0001)
        XCTAssertEqual(reloaded.growth, 78.9, accuracy: 0.0001)
        XCTAssertEqual(reloaded.landmarksPassed, ["windy_pass", "nameless_bend"])
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
