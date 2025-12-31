# FFmpeg Swift

Swift 6.2+ bindings for FFmpeg, supporting cross-platform development with SE-0482 artifact bundles.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / tvOS 26+ / visionOS 26+ / Linux

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wendylabsinc/ffmpeg-swift.git", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "FFmpeg", package: "ffmpeg-swift")
    ])
]
```

### System Dependencies (Development Mode)

By default, the package uses system-installed FFmpeg via pkg-config:

#### macOS
```bash
brew install ffmpeg
```

#### Linux (Debian/Ubuntu)
```bash
sudo apt install libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev
```

## Usage

```swift
import FFmpeg

// Get version info
print("avcodec: \(FFmpegVersion.avcodec)")
print("avformat: \(FFmpegVersion.avformat)")
print("avutil: \(FFmpegVersion.avutil)")
print("swscale: \(FFmpegVersion.swscale)")
print("swresample: \(FFmpegVersion.swresample)")
print("configuration: \(FFmpegVersion.configuration)")

// Access C APIs directly
let codec = avcodec_find_decoder(AV_CODEC_ID_H264)
```

## Cross-Platform Artifact Bundles (Swift 6.2+)

This package supports [SE-0482](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0482-swiftpm-static-library-binary-target-non-apple-platforms.md) cross-platform artifact bundles for distributing pre-built FFmpeg binaries.

### Supported Platforms

| Platform | Architecture | Triple |
|----------|--------------|--------|
| macOS | arm64 | `arm64-apple-macosx` |
| macOS | x86_64 | `x86_64-apple-macosx` |
| Linux | x86_64 | `x86_64-unknown-linux-gnu` |
| Linux | aarch64 | `aarch64-unknown-linux-gnu` |

### Switching to Pre-built Binaries

To use pre-built binaries instead of system libraries, set `useArtifactBundles = true` in Package.swift:

```swift
let useArtifactBundles = true
```

## Building FFmpeg Artifacts

### Triggering a Build

1. **Manual trigger**: Go to Actions → "Build FFmpeg" → Run workflow
2. **Tag release**: Push a tag like `v1.0.0` to automatically build and release

### Creating a Release

1. Push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. The workflow will:
   - Build FFmpeg for all platforms (macOS arm64/x86_64, Linux x86_64/aarch64)
   - Package into SE-0482 artifact bundles
   - Create a GitHub release with the artifacts
   - Compute and append checksums to release notes

3. Update Package.swift with the checksums from the release notes

## Project Structure

```
ffmpeg-swift/
├── Package.swift                 # Main package manifest
├── Sources/
│   ├── FFmpeg/                   # Swift wrapper
│   ├── CFFmpeg/                  # C module map (system library)
│   └── ffmpeg-source/            # FFmpeg git submodule
├── Artifacts/                    # Generated artifact bundles
├── scripts/
│   ├── build-artifacts.sh        # Local build script
│   └── create-artifact-bundles.sh # CI packaging script
└── .github/workflows/
    ├── build-ffmpeg.yml          # Build & release workflow
    └── compute-checksums.yml     # Checksum computation
```

## FFmpeg Libraries Included

- **libavcodec** - Audio/video codec library
- **libavformat** - Container format I/O
- **libavutil** - Utility functions
- **libswscale** - Video scaling and conversion
- **libswresample** - Audio resampling

## License

FFmpeg is licensed under LGPL 2.1+ with optional GPL components. See the [FFmpeg License](https://ffmpeg.org/legal.html) for details.

This Swift package wrapper is MIT licensed.
