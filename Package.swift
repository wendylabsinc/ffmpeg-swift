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
            url: "https://github.com/wendylabsinc/ffmpeg-swift/releases/download/0.0.2/CFFmpeg.artifactbundle.zip",
            checksum: "94a719e9ecece569425f06c3e4d91655e94ca7130fdd9c7cc37613096638e2e3"
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
