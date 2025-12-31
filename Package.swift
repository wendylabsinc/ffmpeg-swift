// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Configuration: Set to true to use pre-built artifact bundles, false for system library
let useArtifactBundles = false

// Version of pre-built FFmpeg binaries (update when releasing new versions)
let artifactVersion = "1.0.0"
let artifactBaseURL = "https://github.com/wendylabsinc/ffmpeg-swift/releases/download/v\(artifactVersion)"

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
    ],
    targets: useArtifactBundles ? [
        // ============================================
        // ARTIFACT BUNDLE CONFIGURATION (Pre-built)
        // ============================================
        .target(
            name: "FFmpeg",
            dependencies: [
                "Clibavcodec",
                "Clibavformat",
                "Clibavutil",
                "Clibswscale",
                "Clibswresample",
            ],
            path: "Sources/FFmpeg"
        ),
        .binaryTarget(
            name: "Clibavcodec",
            url: "\(artifactBaseURL)/libavcodec.artifactbundle.zip",
            checksum: "CHECKSUM_PLACEHOLDER"
        ),
        .binaryTarget(
            name: "Clibavformat",
            url: "\(artifactBaseURL)/libavformat.artifactbundle.zip",
            checksum: "CHECKSUM_PLACEHOLDER"
        ),
        .binaryTarget(
            name: "Clibavutil",
            url: "\(artifactBaseURL)/libavutil.artifactbundle.zip",
            checksum: "CHECKSUM_PLACEHOLDER"
        ),
        .binaryTarget(
            name: "Clibswscale",
            url: "\(artifactBaseURL)/libswscale.artifactbundle.zip",
            checksum: "CHECKSUM_PLACEHOLDER"
        ),
        .binaryTarget(
            name: "Clibswresample",
            url: "\(artifactBaseURL)/libswresample.artifactbundle.zip",
            checksum: "CHECKSUM_PLACEHOLDER"
        ),
        .testTarget(
            name: "FFmpegTests",
            dependencies: ["FFmpeg"]
        ),
    ] : [
        // ============================================
        // SYSTEM LIBRARY CONFIGURATION (Development)
        // ============================================
        .target(
            name: "FFmpeg",
            dependencies: ["CFFmpeg"],
            path: "Sources/FFmpeg"
        ),
        .systemLibrary(
            name: "CFFmpeg",
            path: "Sources/CFFmpeg",
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
