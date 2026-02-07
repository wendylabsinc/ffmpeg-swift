import Foundation
import FFmpeg

let args = Array(CommandLine.arguments.dropFirst())
let inputPath = args.first ?? "Examples/file_example_MP4_1280_10MG.mp4"
let maxFrames = args.dropFirst().first.flatMap { Int($0) } ?? 10

func printUsage() {
    print("Usage: swift run example-filter <input-path> [max-frames]")
}

if args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(0)
}

do {
    let reader = try MediaReader(url: inputPath)
    let graph = try FilterGraph()

    print("Input: \(inputPath)")

    var configured = false
    var count = 0

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
            print("filtered \(count): \(filtered.width)x\(filtered.height) pts=\(filtered.pts)")
            count += 1
            if count >= maxFrames { break }
        }

        if count >= maxFrames { break }
    }

    print("Filtered frames: \(count)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
