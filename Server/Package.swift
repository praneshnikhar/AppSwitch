// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppSwitcher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AppSwitcher",
            path: "Sources"
        ),
    ]
)
