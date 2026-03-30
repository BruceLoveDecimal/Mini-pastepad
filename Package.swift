// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "MiniPasteboard",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MiniPasteboard", targets: ["MiniPasteboard"])
    ],
    targets: [
        .executableTarget(
            name: "MiniPasteboard",
            path: "Sources"
        )
    ]
)
