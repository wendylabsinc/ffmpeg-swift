import Foundation
import FFmpeg

final class ResamplerBox {
    private var resampler: AudioResampler

    init(
        srcChannelLayout: ChannelLayout,
        srcSampleRate: Int32,
        srcFormat: SampleFormat,
        dstChannelLayout: ChannelLayout,
        dstSampleRate: Int32,
        dstFormat: SampleFormat
    ) throws {
        self.resampler = try AudioResampler(
            srcChannelLayout: srcChannelLayout,
            srcSampleRate: srcSampleRate,
            srcFormat: srcFormat,
            dstChannelLayout: dstChannelLayout,
            dstSampleRate: dstSampleRate,
            dstFormat: dstFormat
        )
    }

    @discardableResult
    func convert(source: borrowing Frame, into destination: inout Frame) throws -> Int32 {
        try resampler.convert(source: source, into: &destination)
    }

    @discardableResult
    func flush(into destination: inout Frame) throws -> Int32 {
        try resampler.flush(into: &destination)
    }
}

let args = Array(CommandLine.arguments.dropFirst())
let inputPath = args.first ?? "Examples/file_example_MP4_1280_10MG.mp4"
let outputPath = args.dropFirst().first ?? "Examples/output.mp3"
let maxFrames = args.dropFirst(2).first.flatMap { Int($0) }

func printUsage() {
    print("Usage: swift run example-mp3 <input-path> <output-path> [max-frames]")
}

if args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(0)
}

func preferredLayout(from layout: ChannelLayout) -> ChannelLayout {
    let channels = layout.channelCount
    if channels <= 0 { return .stereo }
    if channels > 2 { return .stereo }
    return layout
}

do {
    guard (try? Codec.findEncoder(id: .mp3)) != nil else {
        fputs("MP3 encoder not available in this FFmpeg build. Rebuild FFmpeg with an MP3 encoder (for example libmp3lame) and regenerate the artifact bundle.\n", stderr)
        exit(1)
    }

    let reader = try MediaReader(url: inputPath)
    if reader.audioStreamIndex < 0 {
        fputs("No audio stream found.\n", stderr)
        exit(1)
    }

    var writer: MediaWriter? = nil
    var resampler: ResamplerBox? = nil

    var targetSampleRate: Int32 = 44_100
    var targetLayout: ChannelLayout = .stereo
    let targetFormat: SampleFormat = .s16p
    var encoderTimeBase = Rational(numerator: 1, denominator: targetSampleRate)
    var lastFrameSamples: Int32 = 0

    var count = 0

    for try await owned in reader.audioFrames() {
        var frame = owned.takeFrame()

        if writer == nil {
            let sourceSampleRate = frame.sampleRate > 0 ? frame.sampleRate : 44_100
            let sourceLayout = frame.channelLayout.channelCount > 0
                ? frame.channelLayout
                : ChannelLayout(channels: 2)

            targetSampleRate = sourceSampleRate
            targetLayout = preferredLayout(from: sourceLayout)
            encoderTimeBase = Rational(numerator: 1, denominator: targetSampleRate)

            let w = try MediaWriter(url: outputPath, formatName: "mp3")
            try w.addAudioStream(
                codecID: .mp3,
                sampleRate: targetSampleRate,
                sampleFormat: targetFormat,
                channelLayout: targetLayout,
                timeBase: encoderTimeBase,
                bitRate: 128_000
            )
            try w.start()
            writer = w

            let needsResample = frame.sampleFormat != targetFormat
                || frame.sampleRate != targetSampleRate
                || sourceLayout.channelCount != targetLayout.channelCount
                || sourceLayout.description != targetLayout.description

            if needsResample {
                resampler = try ResamplerBox(
                    srcChannelLayout: sourceLayout,
                    srcSampleRate: sourceSampleRate,
                    srcFormat: frame.sampleFormat,
                    dstChannelLayout: targetLayout,
                    dstSampleRate: targetSampleRate,
                    dstFormat: targetFormat
                )
            }
        }

        guard let writer = writer else { continue }
        lastFrameSamples = frame.numberOfSamples

        if let resampler = resampler {
            var converted = Frame()
            converted.sampleFormat = targetFormat
            converted.sampleRate = targetSampleRate
            converted.channelLayout = targetLayout
            converted.numberOfSamples = frame.numberOfSamples
            converted.timeBase = encoderTimeBase

            if frame.pts != Int64.min {
                converted.pts = frame.timeBase == encoderTimeBase
                    ? frame.pts
                    : Rational.rescale(frame.pts, from: frame.timeBase, to: encoderTimeBase)
            }

            try converted.allocateBuffers()

            let outSamples = try resampler.convert(source: frame, into: &converted)
            if outSamples > 0 {
                converted.numberOfSamples = outSamples
                try writer.writeAudioFrame(converted)
            }
        } else {
            if frame.pts != Int64.min && frame.timeBase != encoderTimeBase {
                frame.pts = Rational.rescale(frame.pts, from: frame.timeBase, to: encoderTimeBase)
            }
            frame.timeBase = encoderTimeBase
            try writer.writeAudioFrame(frame)
        }

        count += 1
        if let limit = maxFrames, count >= limit { break }
    }

    if let resampler = resampler, let writer = writer {
        var tail = Frame()
        tail.sampleFormat = targetFormat
        tail.sampleRate = targetSampleRate
        tail.channelLayout = targetLayout
        tail.numberOfSamples = max(lastFrameSamples, Int32(1))
        tail.timeBase = encoderTimeBase
        try tail.allocateBuffers()

        let outSamples = try resampler.flush(into: &tail)
        if outSamples > 0 {
            tail.numberOfSamples = outSamples
            try writer.writeAudioFrame(tail)
        }
    }

    try writer?.finish()
    print("Wrote MP3 audio to \(outputPath)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
