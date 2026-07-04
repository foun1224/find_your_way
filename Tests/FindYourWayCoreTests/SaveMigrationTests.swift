import XCTest
@testable import FindYourWayCore

/// T11：schema 1→2 真實遷移（`09_PHASE3_SPEC.md` §5 T11），取代 Phase 2 的假想示範。
final class SaveMigrationTests: XCTestCase {

    // MARK: - MigrationV1toV2（真實遷移：v1 缺 eventsEncountered/companionJoined → 補預設）

    func testMigrationV1toV2UpgradesVersionAndAddsDefaultFields() {
        let migration = MigrationV1toV2()
        let v1Json: [String: Any] = [
            "schemaVersion": 1,
            "distance": 100.0,
            "landmarksPassed": ["windy_pass"],
            "lastActiveTimestamp": 1_000.0,
            "growth": 5.0
        ]

        let migrated = migration.migrate(v1Json)

        XCTAssertEqual(migrated["schemaVersion"] as? Int, 2)
        // 舊資料不丟失。
        XCTAssertEqual(migrated["distance"] as? Double, 100.0)
        XCTAssertEqual(migrated["growth"] as? Double, 5.0)
        XCTAssertEqual(migrated["landmarksPassed"] as? [String], ["windy_pass"])
        XCTAssertEqual(migrated["lastActiveTimestamp"] as? Double, 1_000.0)
        // 新欄位給預設值。
        XCTAssertEqual(migrated["eventsEncountered"] as? [String], [])
        XCTAssertEqual(migrated["companionJoined"] as? Bool, false)
    }

    func testMigrationDeclaresFromAndToVersions() {
        let migration = MigrationV1toV2()
        XCTAssertEqual(migration.fromVersion, 1)
        XCTAssertEqual(migration.toVersion, 2)
    }

    func testMigrationDoesNotOverwriteExistingNewFields() {
        let migration = MigrationV1toV2()
        let jsonWithExistingFields: [String: Any] = [
            "schemaVersion": 1,
            "eventsEncountered": ["wildflower_slope"],
            "companionJoined": true
        ]

        let migrated = migration.migrate(jsonWithExistingFields)

        XCTAssertEqual(migrated["eventsEncountered"] as? [String], ["wildflower_slope"])
        XCTAssertEqual(migrated["companionJoined"] as? Bool, true)
    }

    // MARK: - 當前版本直解 / 缺欄位向後相容（走實際 GameState 解碼路徑）

    func testCurrentVersionDecodesDirectlyWithoutMigration() throws {
        let json = """
        {
            "schemaVersion": \(SaveSchema.currentVersion),
            "distance": 42,
            "landmarksPassed": [],
            "lastActiveTimestamp": 0,
            "growth": 0,
            "eventsEncountered": [],
            "companionJoined": false
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(GameState.self, from: json)
        XCTAssertEqual(state.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(state.distance, 42)
    }

    /// 雙保險（`09` §2.5）：v1 存檔即使不經遷移器，`decodeIfPresent` 也解出安全預設。
    func testV1SaveWithoutRunningMigratorStillDecodesSafeDefaults() throws {
        let json = """
        {
            "schemaVersion": 1,
            "distance": 100,
            "landmarksPassed": ["windy_pass"],
            "lastActiveTimestamp": 500,
            "growth": 5
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(GameState.self, from: json)
        // 舊資料保留。
        XCTAssertEqual(state.distance, 100)
        XCTAssertEqual(state.landmarksPassed, ["windy_pass"])
        XCTAssertEqual(state.growth, 5)
        // 新欄位安全預設。
        XCTAssertEqual(state.eventsEncountered, [])
        XCTAssertFalse(state.companionJoined)
    }

    func testMissingFieldsDecodeWithDefaults() throws {
        let json = """
        { "schemaVersion": 1 }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(GameState.self, from: json)
        XCTAssertEqual(state.distance, 0)
        XCTAssertEqual(state.landmarksPassed, [])
        XCTAssertEqual(state.growth, 0)
        XCTAssertEqual(state.eventsEncountered, [])
        XCTAssertFalse(state.companionJoined)
    }

    // MARK: - version > current 安全降級（透過 SaveStore，不 crash）

    func testFutureVersionSaveFileDoesNotCrashSaveStoreAndFallsBackSafely() throws {
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FindYourWayMigrationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let paths = SavePaths(rootDirectory: tmpRoot)
        try paths.ensureDirectoryExists()

        let futureJson = """
        {
            "schemaVersion": 999,
            "distance": 1,
            "landmarksPassed": [],
            "lastActiveTimestamp": 0,
            "growth": 0,
            "eventsEncountered": [],
            "companionJoined": false
        }
        """.data(using: .utf8)!
        try futureJson.write(to: paths.saveFileURL)

        let store = SaveStore(paths: paths)
        // 不 crash；無有效 .bak 可回退 → 呼叫端可安全以新狀態起步。
        XCTAssertNil(store.load())
    }
}
