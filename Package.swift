// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ffmpeg-swift",
    platforms: [.macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "FFmpeg", targets: ["FFmpeg"]),
    ],
    targets: [
        .binaryTarget(
            name: "CFFmpeg",
            url: "https://github.com/wendylabsinc/ffmpeg-swift/releases/download/0.0.1/CFFmpeg.artifactbundle.zip",
            checksum: "cc73b3315ca0acc7ff80a066f9225e5141b503eaa40edee797054bae1d7d632e"
        ),
        .target(
            name: "CFFmpegShim",
            dependencies: ["CFFmpeg"],
            publicHeadersPath: "include",
            cSettings: [.define("__STDC_CONSTANT_MACROS")]
        ),
        .target(name: "FFmpeg", dependencies: ["CFFmpegShim"]),
        .testTarget(name: "FFmpegTests", dependencies: ["FFmpeg"]),
    ]
)
