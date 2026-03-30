// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "camera-capture",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CameraCaptureCore",
            targets: ["CameraCaptureCore"]
        ),
        .executable(
            name: "camera-capture",
            targets: ["camera-capture"]
        ),
        .executable(
            name: "camera-capture-helper",
            targets: ["camera-capture-helper"]
        ),
    ],
    targets: [
        .target(
            name: "CameraCaptureCore"
        ),
        .executableTarget(
            name: "camera-capture",
            dependencies: ["CameraCaptureCore"]
        ),
        .executableTarget(
            name: "camera-capture-helper",
            dependencies: ["CameraCaptureCore"]
        ),
        .testTarget(
            name: "CameraCaptureCoreTests",
            dependencies: ["CameraCaptureCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
