// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacDeck",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacDeck",
            path: "Sources"
        ),
    ]
)
