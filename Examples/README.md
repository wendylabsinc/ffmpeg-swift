# Examples

These examples show how to use the high-level `FFmpeg` API. They are intentionally small and focus on one concept at a time.

## 1) Inspect streams and duration

```swift
import FFmpeg

let ctx = try FormatContext.openInput(url: "input.mp4")

print("Duration (s):", ctx.durationSeconds ?? -1)

for stream in ctx.streams {
    print("#\(stream.index) type=\(stream.mediaType) codec=\(stream.codecID) timeBase=\(stream.timeBase)")
}
```

## 2) Decode video frames with `MediaReader`

```swift
import FFmpeg

let reader = try MediaReader(url: "input.mp4")

for try await owned in reader.videoFrames() {
    let frame = owned.takeFrame()
    print("frame: \(frame.width)x\(frame.height) pts=\(frame.pts)")
}
```

## 3) Scale frames with `VideoScaler`

```swift
import FFmpeg

let reader = try MediaReader(url: "input.mp4")

for try await owned in reader.videoFrames() {
    var src = owned.takeFrame()

    var dst = Frame()
    dst.width = 320
    dst.height = 240
    dst.pixelFormat = src.pixelFormat
    try dst.allocateBuffers()

    let scaler = try VideoScaler(
        srcWidth: src.width,
        srcHeight: src.height,
        srcFormat: src.pixelFormat,
        dstWidth: dst.width,
        dstHeight: dst.height,
        dstFormat: dst.pixelFormat
    )

    try scaler.scale(source: src, into: &dst)

    // Use dst...
}
```

## 4) Filter frames with `FilterGraph`

```swift
import FFmpeg

let reader = try MediaReader(url: "input.mp4")
let graph = try FilterGraph()

// Example: scale + hflip (configure lazily from first frame)
var configured = false

for try await owned in reader.videoFrames() {
    var frame = owned.takeFrame()
    if !configured {
        try graph.configureVideo(
            filterDescription: "scale=320:240,hflip",
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat,
            timeBase: frame.timeBase
        )
        configured = true
    }
    try graph.push(frame: frame)

    var filtered = Frame()
    while true {
        let result = try graph.pull(into: &filtered)
        if result != .success { break }
        // Use filtered...
    }
}
```

## 5) Encode with `MediaWriter`

```swift
import FFmpeg
import CFFmpegShim

let reader = try MediaReader(url: "input.mp4")
var writer: MediaWriter? = nil
let timeBase = Rational(numerator: 1, denominator: 30)

for try await owned in reader.videoFrames() {
    let frame = owned.takeFrame()
    if writer == nil {
        let w = try MediaWriter(url: "output.mp4", formatName: "mp4")
        try w.addVideoStream(
            codecID: AV_CODEC_ID_H264,
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat,
            timeBase: timeBase
        )
        try w.start()
        writer = w
    }
    try writer?.writeVideoFrame(frame)
}

try writer?.finish()
```
