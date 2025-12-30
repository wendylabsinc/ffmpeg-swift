// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FFmpeg",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "FFmpeg",
            targets: ["FFmpeg"]
        ),
        // Individual FFmpeg libraries for granular imports
        .library(name: "CFFmpeg", targets: ["CFFmpeg"]),
    ],
    targets: [
        // Swift wrapper target
        .target(
            name: "FFmpeg",
            dependencies: ["CFFmpeg"]
        ),
        // C bindings for FFmpeg - will use artifact bundles for pre-built binaries
        // For now, this is a system library target that expects FFmpeg to be installed
        // In the future, we'll use .binaryTarget with artifact bundles for cross-platform support
        .systemLibrary(
            name: "CFFmpeg",
            pkgConfig: "libavcodec libavformat libavutil libswscale libswresample",
            providers: [
                .brew(["ffmpeg"]),
                .apt(["libavcodec-dev", "libavformat-dev", "libavutil-dev", "libswscale-dev", "libswresample-dev"]),
            ]
        ),
        .testTarget(
            name: "FFmpegTests",
            dependencies: ["FFmpeg"]
        ),
    ]
)
