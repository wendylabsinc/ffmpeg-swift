# FFmpeg Swift

Swift 6.2+ bindings for FFmpeg, supporting cross-platform development.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / tvOS 26+ / visionOS 26+ / Linux

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wendylabsinc/ffmpeg-swift.git", from: "1.0.0")
]
```

### System Dependencies

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

// Access C APIs directly
import CFFmpeg
let codec = avcodec_find_decoder(AV_CODEC_ID_H264)
```

## Cross-Platform Artifact Bundles (Swift 6.2+)

This package supports Swift 6.2's new cross-platform artifact bundles for distributing pre-built FFmpeg binaries. See `Package.swift.artifact-bundle-example` for configuration.

## FFmpeg Source

The FFmpeg source code is included as a git submodule in `Sources/ffmpeg-source/` for reference and building custom binaries.

## License

FFmpeg is licensed under LGPL/GPL. See the FFmpeg source for details.
