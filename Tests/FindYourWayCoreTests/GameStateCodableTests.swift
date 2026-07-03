import XCTest
@testable import FindYourWayCore

final class GameStateCodableTests: XCTestCase {

    func testRoundTripIsEqual() throws {
        let state = GameState(
            schemaVersion: 1,
            distance: 12_345.6,
            landmarksPassed: ["windy_pass", "nameless_bend"],
            lastActiveTimestamp: 1_751_500_000,
            growth: 42.5
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func testEncodedJSONContainsExpectedKeys() throws {
        let state = GameState(distance: 1)
        let data = try JSONEncoder().encode(state)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["schemaVersion"])
        XCTAssertNotNil(json?["distance"])
        XCTAssertNotNil(json?["landmarksPassed"])
        XCTAssertNotNil(json?["lastActiveTimestamp"])
        XCTAssertNotNil(json?["growth"])
    }

    func testDecodingMissingFieldsFallsBackToDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GameState.self, from: json)

        XCTAssertEqual(decoded.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(decoded.distance, 0)
        XCTAssertEqual(decoded.landmarksPassed, [])
        XCTAssertEqual(decoded.lastActiveTimestamp, 0)
        XCTAssertEqual(decoded.growth, 0)
    }

    func testDecodingPartialFieldsKeepsProvidedValuesAndDefaultsRest() throws {
        let json = """
        { "distance": 500 }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GameState.self, from: json)

        XCTAssertEqual(decoded.distance, 500)
        XCTAssertEqual(decoded.landmarksPassed, [])
        XCTAssertEqual(decoded.growth, 0)
    }

    func testRoundTripIsIdempotent() throws {
        let state = GameState(distance: 99, landmarksPassed: ["a"], lastActiveTimestamp: 5, growth: 1)
        let data1 = try JSONEncoder().encode(state)
        let decoded1 = try JSONDecoder().decode(GameState.self, from: data1)
        let data2 = try JSONEncoder().encode(decoded1)
        let decoded2 = try JSONDecoder().decode(GameState.self, from: data2)

        XCTAssertEqual(decoded1, decoded2)
    }
}
