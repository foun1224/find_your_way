// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FindYourWay",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // 「可測邏輯」library target：不含 @main，不 import AppKit runtime 的難測行為。
        .target(
            name: "FindYourWayCore",
            dependencies: []
        ),
        // executable target：薄殼，只做組裝（NSApplication / NSWindow / SKView）。
        .executableTarget(
            name: "FindYourWay",
            dependencies: ["FindYourWayCore"]
        ),
        .testTarget(
            name: "FindYourWayCoreTests",
            dependencies: ["FindYourWayCore"]
        )
    ]
)
