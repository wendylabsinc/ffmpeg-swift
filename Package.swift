// swift-tools-version: 6.2
import Foundation
import PackageDescription

let localArtifactPath = "CFFmpeg.artifactbundle"
let useLocalArtifact = ProcessInfo.processInfo.environment["FFMPEG_SWIFT_USE_LOCAL_ARTIFACT"] == "1"
let hasLocalArtifact = FileManager.default.fileExists(atPath: localArtifactPath)

let cffmpegTarget: Target = {
    if useLocalArtifact && hasLocalArtifact {
        return .binaryTarget(
            name: "CFFmpeg",
            path: localArtifactPath
        )
    }

    return .binaryTarget(
        name: "CFFmpeg",
        url: "https://github.com/wendylabsinc/ffmpeg-swift/releases/download/0.0.2/CFFmpeg.artifactbundle.zip",
        checksum: "d69502cc3ed5b097e4a573bdd719e8e74d88292d0d97e397f8fc0ab002dc3fc7"
    )
}()

let package = Package(
    name: "ffmpeg-swift",
    platforms: [.macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "FFmpeg", targets: ["FFmpeg"]),
        .executable(name: "example-inspect", targets: ["ExampleInspect"]),
        .executable(name: "example-decode", targets: ["ExampleDecode"]),
        .executable(name: "example-filter", targets: ["ExampleFilter"]),
        .executable(name: "example-encode", targets: ["ExampleEncode"]),
        .executable(name: "example-adts", targets: ["ExampleADTS"]),
        .executable(name: "example-mp3", targets: ["ExampleMP3"]),
    ],
    targets: [
        cffmpegTarget,
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
            dependencies: ["FFmpeg"],
            path: "Examples/Encode"
        ),
        .executableTarget(
            name: "ExampleADTS",
            dependencies: ["FFmpeg"],
            path: "Examples/ADTS"
        ),
        .executableTarget(
            name: "ExampleMP3",
            dependencies: ["FFmpeg"],
            path: "Examples/MP3"
        ),
        .testTarget(name: "FFmpegTests", dependencies: ["FFmpeg"]),
    ]
)
