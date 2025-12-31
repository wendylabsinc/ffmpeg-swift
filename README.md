# FFmpeg Swift

[![Build FFmpeg](https://github.com/wendylabsinc/ffmpeg-swift/actions/workflows/build-ffmpeg.yml/badge.svg)](https://github.com/wendylabsinc/ffmpeg-swift/actions/workflows/build-ffmpeg.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20visionOS%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Swift 6.2+ bindings for FFmpeg with cross-platform artifact bundle support ([SE-0482](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0482-swiftpm-static-library-binary-target-non-apple-platforms.md)).

> **⚠️ Requires Swift 6.2+**
> This package uses Swift 6.2's cross-platform artifact bundles feature for distributing pre-built FFmpeg binaries across macOS and Linux. It will not work with earlier Swift versions.

## Installation

Add the package to your `Package.swift`:

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/wendylabsinc/ffmpeg-swift.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "FFmpeg", package: "ffmpeg-swift")
            ]
        )
    ]
)
```

### Why Swift 6.2?

Swift 6.2 introduced [SE-0482: Swift Package Manager Support for Static Library Binary Targets on Non-Apple Platforms](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0482-swiftpm-static-library-binary-target-non-apple-platforms.md), which enables:

- **Cross-platform binary distribution** - Pre-built FFmpeg libraries for macOS and Linux
- **No system dependencies** - Users don't need to install FFmpeg via Homebrew or apt
- **Consistent builds** - Same FFmpeg version across all platforms

### System Dependencies (Development Mode)

By default, the package uses system-installed FFmpeg. Install via:

```bash
# macOS
brew install ffmpeg

# Linux (Debian/Ubuntu)
sudo apt install libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev
```

## Usage

```swift
import FFmpeg

// Get library versions (Comparable, so you can check minimum versions)
let avcodec = FFmpeg.Version.avcodec
print("libavcodec: \(avcodec)")  // "61.19.100"

if avcodec >= Version(major: 61, minor: 0, patch: 0) {
    print("Using FFmpeg 7.x!")
}

// Build info
print("License: \(FFmpeg.license)")
print("Configuration: \(FFmpeg.configuration)")

// Find codecs with Swift-y API
if let h264 = Codec.decoder(for: AV_CODEC_ID_H264) {
    print("Found: \(h264.longName)")  // "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10"
    print("Is decoder: \(h264.isDecoder)")  // true
}

if let aac = Codec.encoder(named: "aac") {
    print("AAC encoder: \(aac.name)")
}

// Error handling with Swift errors
do {
    try FFmpegError.check(someFFmpegOperation())
} catch let error as FFmpegError {
    print("FFmpeg error: \(error.message)")
}

// Access C APIs directly when needed
let codec = avcodec_find_decoder(AV_CODEC_ID_H264)
```

## API Overview

The package provides Swift-idiomatic wrappers while exposing the full C API:

| Type | Description |
|------|-------------|
| `FFmpeg.Version` | Library version information |
| `Version` | Comparable semantic version type |
| `Codec` | Swift wrapper for `AVCodec` with static lookup methods |
| `FFmpegError` | Swift `Error` type wrapping FFmpeg error codes |
| `AVPixelFormat` extensions | `CustomStringConvertible`, named lookup |
| `AVSampleFormat` extensions | `CustomStringConvertible`, `bytesPerSample`, `isPlanar` |

All underlying C types (`AVCodec`, `AVFrame`, `AVPacket`, etc.) are available via `@_exported import`.

## Supported Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| macOS 26+ | arm64 | ✅ |
| macOS 26+ | x86_64 | ✅ |
| iOS 26+ | arm64 | ✅ |
| tvOS 26+ | arm64 | ✅ |
| visionOS 26+ | arm64 | ✅ |
| Linux | x86_64 | ✅ |
| Linux | aarch64 | ✅ |

## Local Development

### Prerequisites

1. **Swift 6.2+** - Install from [swift.org](https://swift.org/download/) or Xcode 26+
2. **FFmpeg** - System installation for development

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install libavcodec-dev libavformat-dev libavutil-dev \
    libswscale-dev libswresample-dev pkg-config
```

### Clone and Build

```bash
# Clone with submodules
git clone --recursive https://github.com/wendylabsinc/ffmpeg-swift.git
cd ffmpeg-swift

# Build
swift build

# Run tests
swift test
```

### Project Structure

```
ffmpeg-swift/
├── Package.swift                    # Package manifest
├── Sources/
│   ├── FFmpeg/
│   │   └── FFmpeg.swift             # Swift API wrappers
│   ├── CFFmpeg/
│   │   ├── module.modulemap         # C module definition
│   │   └── shim.h                   # FFmpeg header imports
│   └── ffmpeg-source/               # FFmpeg git submodule (reference)
├── Tests/
│   └── FFmpegTests/
├── Artifacts/                       # Generated artifact bundles
├── scripts/
│   ├── build-artifacts.sh           # Local multi-platform build
│   └── create-artifact-bundles.sh   # CI artifact packaging
└── .github/workflows/
    ├── build-ffmpeg.yml             # Build & release workflow
    └── compute-checksums.yml        # Checksum computation
```

### Switching Between Configurations

The package supports two modes controlled by `useArtifactBundles` in Package.swift:

```swift
// Use system-installed FFmpeg (default, for development)
let useArtifactBundles = false

// Use pre-built artifact bundles (for distribution)
let useArtifactBundles = true
```

### Building Artifact Bundles Locally

```bash
# Build FFmpeg for current platform
cd Sources/ffmpeg-source
./configure --prefix=$(pwd)/../../build/local \
    --enable-static --disable-shared \
    --disable-programs --disable-doc
make -j$(nproc)
make install
```

### Creating a Release

1. Tag and push:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. GitHub Actions will:
   - Build FFmpeg for all 4 platform/arch combinations
   - Package into SE-0482 artifact bundles
   - Create release with artifacts attached
   - Compute and append Swift package checksums

3. Update `Package.swift` with checksums from release notes

## FFmpeg Libraries Included

| Library | Description |
|---------|-------------|
| libavcodec | Audio/video codec encoding and decoding |
| libavformat | Container format I/O and muxing/demuxing |
| libavutil | Utility functions (memory, math, logging) |
| libswscale | Video scaling and pixel format conversion |
| libswresample | Audio resampling and format conversion |

## License

- **This Swift package**: MIT License
- **FFmpeg**: LGPL 2.1+ / GPL (depending on build configuration)

See [FFmpeg License](https://ffmpeg.org/legal.html) for details on FFmpeg licensing.
