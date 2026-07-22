// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TurboMouse",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CHID"),
        .executableTarget(
            name: "TurboMouse",
            dependencies: ["CHID"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
    ]
)
