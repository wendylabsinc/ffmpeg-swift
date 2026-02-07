import Foundation
import FFmpeg

let args = Array(CommandLine.arguments.dropFirst())
let inputPath = args.first ?? "Examples/file_example_MP4_1280_10MG.mp4"
let outputPath = args.dropFirst().first ?? "Examples/output.adts"

func printUsage() {
    print("Usage: swift run example-adts <input-path> <output-path>")
}

if args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(0)
}

do {
    let input = try FormatContext.openInput(url: inputPath)
    let audioIndex = try input.findBestStream(type: .audio)
    let audioStream = input.stream(at: Int(audioIndex))

    guard audioStream.codecID == .aac else {
        fputs("Input audio codec is \(audioStream.codecID). This example remuxes AAC to ADTS.\n", stderr)
        exit(1)
    }

    let output = try FormatContext.openOutput(url: outputPath, formatName: "adts")
    let outStream = try output.addStream()
    try audioStream.copyCodecParameters(to: outStream)

    try output.openIO(url: outputPath)
    try output.writeHeader()

    var packet = Packet()
    while try input.readFrame(into: &packet) {
        defer { packet.unref() }
        guard packet.streamIndex == audioIndex else { continue }
        packet.rescaleTimestamps(from: audioStream.timeBase, to: outStream.timeBase)
        packet.streamIndex = outStream.index
        try output.writeInterleavedFrame(packet: &packet)
    }

    try output.writeTrailer()
    print("Wrote ADTS to \(outputPath)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
