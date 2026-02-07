import Foundation
import FFmpeg

let args = Array(CommandLine.arguments.dropFirst())
let inputPath = args.first ?? "Examples/file_example_MP4_1280_10MG.mp4"
let maxFrames = args.dropFirst().first.flatMap { Int($0) } ?? 10

func printUsage() {
    print("Usage: swift run example-decode <input-path> [max-frames]")
}

if args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(0)
}

do {
    let reader = try MediaReader(url: inputPath)
    print("Input: \(inputPath)")
    print("Duration (s):", reader.durationSeconds ?? -1)

    var count = 0
    for try await frame in reader.videoFrames() {
        print("frame \(count): \(frame.width)x\(frame.height) pts=\(frame.pts)")
        count += 1
        if count >= maxFrames { break }
    }

    print("Decoded frames: \(count)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
