import Foundation
import FFmpeg
import CFFmpegShim

let args = Array(CommandLine.arguments.dropFirst())
let inputPath = args.first ?? "Examples/file_example_MP4_1280_10MG.mp4"
let outputPath = args.dropFirst().first ?? "Examples/output.mp4"
let maxFrames = args.dropFirst(2).first.flatMap { Int($0) } ?? 60

func printUsage() {
    print("Usage: swift run example-encode <input-path> <output-path> [max-frames]")
}

if args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(0)
}

do {
    let reader = try MediaReader(url: inputPath)
    if reader.videoStreamIndex < 0 {
        fputs("No video stream found.\n", stderr)
        exit(1)
    }

    let timeBase = reader.formatContext.stream(at: Int(reader.videoStreamIndex)).timeBase

    var writer: MediaWriter? = nil
    var count = 0

    for try await owned in reader.videoFrames() {
        let frame = owned.takeFrame()

        if writer == nil {
            let w = try MediaWriter(url: outputPath, formatName: "mp4")
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
        count += 1
        if count >= maxFrames { break }
    }

    try writer?.finish()
    print("Wrote \(count) frames to \(outputPath)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
