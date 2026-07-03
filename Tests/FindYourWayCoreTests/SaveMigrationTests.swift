import XCTest
@testable import FindYourWayCore

final class SaveMigrationTests: XCTestCase {

    // MARK: - MigrationV1toV2（示範用遷移骨架）

    func testMigrationV1toV2UpgradesVersionAndAddsDefaultField() {
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
        // 舊資料不丟失
        XCTAssertEqual(migrated["distance"] as? Double, 100.0)
        XCTAssertEqual(migrated["growth"] as? Double, 5.0)
        XCTAssertEqual(migrated["landmarksPassed"] as? [String], ["windy_pass"])
        // 新欄位給預設值
        XCTAssertEqual(migrated["growthStages"] as? [String], [])
    }

    func testMigrationDeclaresFromAndToVersions() {
        let migration = MigrationV1toV2()
        XCTAssertEqual(migration.fromVersion, 1)
        XCTAssertEqual(migration.toVersion, 2)
    }

    func testMigrationDoesNotOverwriteExistingNewField() {
        let migration = MigrationV1toV2()
        let jsonWithExistingField: [String: Any] = [
            "schemaVersion": 1,
            "growthStages": ["seedling"]
        ]

        let migrated = migration.migrate(jsonWithExistingField)

        XCTAssertEqual(migrated["growthStages"] as? [String], ["seedling"])
    }

    // MARK: - 當前版本直解 / 缺欄位向後相容（走實際 GameState 解碼路徑）

    func testCurrentVersionDecodesDirectlyWithoutMigration() throws {
        let json = """
        {
            "schemaVersion": \(SaveSchema.currentVersion),
            "distance": 42,
            "landmarksPassed": [],
            "lastActiveTimestamp": 0,
            "growth": 0
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(GameState.self, from: json)
        XCTAssertEqual(state.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(state.distance, 42)
    }

    func testMissingFieldsDecodeWithDefaults() throws {
        let json = """
        { "schemaVersion": 1 }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(GameState.self, from: json)
        XCTAssertEqual(state.distance, 0)
        XCTAssertEqual(state.landmarksPassed, [])
        XCTAssertEqual(state.growth, 0)
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
            "growth": 0
        }
        """.data(using: .utf8)!
        try futureJson.write(to: paths.saveFileURL)

        let store = SaveStore(paths: paths)
        // 不 crash；無有效 .bak 可回退 → 呼叫端可安全以新狀態起步。
        XCTAssertNil(store.load())
    }
}
