// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ffmpeg-swift",
    platforms: [.macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "FFmpeg", targets: ["FFmpeg"]),
        .executable(name: "example-inspect", targets: ["ExampleInspect"]),
        .executable(name: "example-decode", targets: ["ExampleDecode"]),
        .executable(name: "example-filter", targets: ["ExampleFilter"]),
        .executable(name: "example-encode", targets: ["ExampleEncode"]),
    ],
    targets: [
        .binaryTarget(
            name: "CFFmpeg",
            url: "https://github.com/wendylabsinc/ffmpeg-swift/releases/download/0.0.2/CFFmpeg.artifactbundle.zip",
            checksum: "02b8764e2488eff13e4ba9d8fbbad2bc5f01d6abf941df783b501662dfdf6665"
        ),
        .target(
            name: "CFFmpegShim",
            dependencies: ["CFFmpeg"],
            publicHeadersPath: "include",
            cSettings: [.define("__STDC_CONSTANT_MACROS")]
        ),
        .target(name: "FFmpeg", dependencies: ["CFFmpegShim"]),
        .executableTarget(
            name: "ExampleInspect",
            dependencies: ["FFmpeg"],
            path: "Examples/Inspect"
        ),
        .executableTarget(
            name: "ExampleDecode",
            dependencies: ["FFmpeg"],
            path: "Examples/Decode"
        ),
        .executableTarget(
            name: "ExampleFilter",
            dependencies: ["FFmpeg"],
            path: "Examples/Filter"
        ),
        .executableTarget(
            name: "ExampleEncode",
            dependencies: ["FFmpeg", "CFFmpegShim"],
            path: "Examples/Encode"
        ),
        .testTarget(name: "FFmpegTests", dependencies: ["FFmpeg"]),
    ]
)
