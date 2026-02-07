import Foundation
import FFmpeg

let args = Array(CommandLine.arguments.dropFirst())
let inputPath = args.first ?? "Examples/file_example_MP4_1280_10MG.mp4"

func formatMediaType(_ type: MediaType) -> String {
    type.description
}

do {
    let ctx = try FormatContext.openInput(url: inputPath)

    print("Input: \(inputPath)")
    print("Duration (s):", ctx.durationSeconds ?? -1)
    print("Streams: \(ctx.streamCount)")

    for stream in ctx.streams {
        let type = formatMediaType(stream.mediaType)
        print("#\(stream.index) type=\(type) codec=\(stream.codecID) timeBase=\(stream.timeBase)")
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
