# ffmpeg-swift

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20Linux%20|%20Windows%20|%20Android-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![macOS](https://img.shields.io/github/actions/workflow/status/wendylabsinc/ffmpeg-swift/ci.yml?branch=main&label=macOS)](https://github.com/wendylabsinc/ffmpeg-swift/actions/workflows/ci.yml)
[![Linux](https://img.shields.io/github/actions/workflow/status/wendylabsinc/ffmpeg-swift/ci.yml?branch=main&label=Linux)](https://github.com/wendylabsinc/ffmpeg-swift/actions/workflows/ci.yml)
[![Windows](https://img.shields.io/github/actions/workflow/status/wendylabsinc/ffmpeg-swift/ci.yml?branch=main&label=Windows)](https://github.com/wendylabsinc/ffmpeg-swift/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-blue)](https://swiftpackageindex.com/wendylabsinc/ffmpeg-swift/documentation)

A type-safe, memory-safe Swift package that distributes FFmpeg 7.1 as pre-built static libraries via [SE-0482 artifact bundles](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0482-swiftpm-binary-target-static-lib.md). Any Swift project can `import FFmpeg` and use FFmpeg on macOS and Linux without installing FFmpeg system-wide.

## Platform Support

| Platform | Architecture | Status |
|----------|-------------|--------|
| macOS | arm64 (Apple Silicon) | Supported |
| macOS | x86_64 (Intel) | Supported |
| iOS | arm64 | Supported |
| tvOS | arm64 | Supported |
| watchOS | arm64 | Supported |
| Linux | x86_64 | Supported |
| Linux | aarch64 | Supported |
| Windows | x86_64 | Supported |
| Windows | arm64 | Supported |

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wendylabsinc/ffmpeg-swift.git", from: "0.0.1"),
]
```

Then add `"FFmpeg"` as a dependency of your target:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "FFmpeg", package: "ffmpeg-swift"),
])
```

## Architecture

```
┌─────────────────────────────┐
│  FFmpeg  (Swift module)     │  Ergonomic, type-safe, memory-safe Swift API
├─────────────────────────────┤
│  CFFmpegShim  (C target)    │  Bridges C macros → Swift-importable constants/functions
├─────────────────────────────┤
│  CFFmpeg  (binaryTarget)    │  SE-0482 artifact bundle with static libs + headers
└─────────────────────────────┘
```

**Why three layers?** FFmpeg uses complex C macros (`AVERROR(EAGAIN)`, `AV_NOPTS_VALUE`, `av_err2str`) that Swift cannot import. The shim layer exposes these as `static const` / `static inline` functions.

## Quick Start

```swift
import FFmpeg

// Check FFmpeg version
print(FFmpegLibrary.avutilVersion) // "7.1"

// Discover codecs
let codec = try Codec.findDecoder(name: "h264")

// Allocate frames and packets (move-only, auto-freed)
var frame = Frame()
frame.width = 1920
frame.height = 1080

var packet = Packet()
```

### Decode a Video File

```swift
let reader = try MediaReader(url: "input.mp4")

print("Duration: \(reader.durationSeconds ?? 0)s")
print("Streams: \(reader.streams.count)")

for try await frame in reader.videoFrames() {
    print("Frame: \(frame.width)x\(frame.height) pts=\(frame.pts)")
}
```

### Manual Decode Loop

```swift
let fmt = try FormatContext.openInput(url: "input.mp4")
let videoIdx = try fmt.findBestStream(type: AVMEDIA_TYPE_VIDEO)
let stream = fmt.stream(at: Int(videoIdx))

let codec = try Codec.findDecoder(id: stream.codecID)
let ctx = try CodecContext(codec: codec)
try ctx.setParameters(from: stream.codecParameters)
try ctx.open()

var packet = Packet()
var frame = Frame()

while try fmt.readFrame(into: &packet) {
    guard packet.streamIndex == videoIdx else {
        packet.unref()
        continue
    }
    _ = try ctx.sendPacket(packet)
    packet.unref()

    while case .success = try ctx.receiveFrame(into: &frame) {
        // Process frame...
        frame.unref()
    }
}
```

### Video Scaling

```swift
let scaler = try VideoScaler(
    srcWidth: 1920, srcHeight: 1080, srcFormat: AV_PIX_FMT_YUV420P,
    dstWidth: 640, dstHeight: 360, dstFormat: AV_PIX_FMT_RGB24
)

var dst = Frame()
dst.width = 640
dst.height = 360
dst.pixelFormat = AV_PIX_FMT_RGB24
try dst.allocateBuffers()

try scaler.scale(source: srcFrame, into: &dst)
```

### Filter Graphs

```swift
let graph = try FilterGraph()
try graph.configureVideo(
    filterDescription: "scale=320:240,hflip",
    width: 1920, height: 1080,
    pixelFormat: AV_PIX_FMT_YUV420P,
    timeBase: Rational(numerator: 1, denominator: 30)
)

try graph.push(frame: inputFrame)
var filtered = Frame()
while case .success = try graph.pull(into: &filtered) {
    // Process filtered frame...
    filtered.unref()
}
```

## API Overview

| Type | Description |
|------|-------------|
| `Frame` | ~Copyable wrapper around `AVFrame*`, auto-freed |
| `Packet` | ~Copyable wrapper around `AVPacket*`, auto-freed |
| `FormatContext` | Demuxing (input) and muxing (output) |
| `CodecContext` | Encoding and decoding with `CodecResult` enum |
| `Codec` | Codec discovery by name or ID |
| `VideoScaler` | ~Copyable `SwsContext` wrapper, uses `sws_scale_frame` |
| `AudioResampler` | ~Copyable `SwrContext` wrapper |
| `FilterGraph` | String-based filter graph configuration |
| `MediaReader` | High-level async decoded frame streams |
| `MediaWriter` | High-level frame encoder + muxer |
| `FFmpegError` | Type-safe error with well-known static properties |
| `Rational` | `AVRational` wrapper with arithmetic |
| `AVDictionaryWrapper` | Safe dictionary for FFmpeg options |
| `OwnedFrame` | Copyable/Sendable frame wrapper for async streams |

## Building the Artifact Bundle

To build the FFmpeg static libraries from source:

```bash
# Build for current platform only
./Scripts/build-ffmpeg.sh

# Build for specific platforms
./Scripts/build-ffmpeg.sh --platforms macos-arm64,macos-x86_64

# Build all platforms (Linux via Docker when on macOS)
./Scripts/build-ffmpeg.sh --platforms macos-arm64,macos-x86_64,linux-x86_64,linux-aarch64

# Build and zip for release
./Scripts/build-ffmpeg.sh --zip
```

The script downloads FFmpeg 7.1 source, builds static libraries, merges them into a single `libcffmpeg.a`, and assembles the SE-0482 artifact bundle.

## Included FFmpeg Libraries

- libavutil
- libavcodec
- libavformat
- libavfilter
- libswscale
- libswresample
- libpostproc

## Requirements

- Swift 6.2+ (SE-0482 static library artifact bundles require Swift 6.2+)
- macOS 14+, iOS 16+, tvOS 16+, watchOS 9+, or Linux

## License

FFmpeg is licensed under LGPL 2.1+ / GPL 2+ depending on configuration. This package builds FFmpeg with `--enable-gpl --enable-version3`.
