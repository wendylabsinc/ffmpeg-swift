import CFFmpegShim

/// High-level media file writer for encoding and muxing frames.
public final class MediaWriter: @unchecked Sendable {
    /// The underlying output format context.
    public let formatContext: FormatContext
    private let url: String

    private var videoEncoderContext: CodecContext?
    private var audioEncoderContext: CodecContext?

    /// Video stream index in the output, or `-1` if not set.
    public private(set) var videoStreamIndex: Int32 = -1
    /// Audio stream index in the output, or `-1` if not set.
    public private(set) var audioStreamIndex: Int32 = -1

    private var headerWritten = false

    /// Creates a media writer for the given output URL.
    public init(url: String, formatName: String? = nil) throws {
        self.url = url
        self.formatContext = try FormatContext.openOutput(url: url, formatName: formatName)
    }

    /// Adds a video stream with the given codec and parameters.
    ///
    /// - Parameters:
    ///   - codecID: The codec ID (e.g. `AV_CODEC_ID_H264`).
    ///   - width: Video width.
    ///   - height: Video height.
    ///   - pixelFormat: Pixel format.
    ///   - timeBase: Time base for the stream.
    ///   - bitRate: Target bit rate.
    ///   - gopSize: GOP size.
    ///   - maxBFrames: Maximum number of B-frames.
    /// - Returns: The configured encoder context.
    @discardableResult
    public func addVideoStream(
        codecID: AVCodecID,
        width: Int32,
        height: Int32,
        pixelFormat: AVPixelFormat,
        timeBase: Rational,
        bitRate: Int64 = 0,
        gopSize: Int32 = 12,
        maxBFrames: Int32 = 0
    ) throws -> CodecContext {
        let codec = try Codec.findEncoder(id: codecID)
        let stream = try formatContext.addStream(codec: codec)

        let ctx = try CodecContext(codec: codec)
        ctx.width = width
        ctx.height = height
        ctx.pixelFormat = pixelFormat
        ctx.timeBase = timeBase
        ctx.bitRate = bitRate
        ctx.gopSize = gopSize
        ctx.maxBFrames = maxBFrames

        if (formatContext.pointer.pointee.oformat.pointee.flags & cffmpeg_AVFMT_GLOBALHEADER) != 0 {
            ctx.flags |= cffmpeg_AV_CODEC_FLAG_GLOBAL_HEADER
        }

        try ctx.open()
        try ctx.copyParameters(to: stream.pointee.codecpar)
        stream.pointee.time_base = timeBase.avRational

        videoStreamIndex = Int32(stream.pointee.index)
        videoEncoderContext = ctx
        return ctx
    }

    /// Adds an audio stream with the given codec and parameters.
    @discardableResult
    public func addAudioStream(
        codecID: AVCodecID,
        sampleRate: Int32,
        sampleFormat: AVSampleFormat,
        channelLayout: AVChannelLayout,
        timeBase: Rational,
        bitRate: Int64 = 0
    ) throws -> CodecContext {
        let codec = try Codec.findEncoder(id: codecID)
        let stream = try formatContext.addStream(codec: codec)

        let ctx = try CodecContext(codec: codec)
        ctx.sampleRate = sampleRate
        ctx.sampleFormat = sampleFormat
        ctx.channelLayout = channelLayout
        ctx.timeBase = timeBase
        ctx.bitRate = bitRate

        if (formatContext.pointer.pointee.oformat.pointee.flags & cffmpeg_AVFMT_GLOBALHEADER) != 0 {
            ctx.flags |= cffmpeg_AV_CODEC_FLAG_GLOBAL_HEADER
        }

        try ctx.open()
        try ctx.copyParameters(to: stream.pointee.codecpar)
        stream.pointee.time_base = timeBase.avRational

        audioStreamIndex = Int32(stream.pointee.index)
        audioEncoderContext = ctx
        return ctx
    }

    /// Opens the output file and writes the header.
    /// Call after adding all streams.
    public func start() throws {
        try formatContext.openIO(url: url)
        try formatContext.writeHeader()
        headerWritten = true
    }

    /// Encodes and writes a video frame.
    public func writeVideoFrame(_ frame: borrowing Frame) throws {
        guard let encoder = videoEncoderContext else {
            throw FFmpegError.encoderNotFound
        }
        try encodeAndWrite(frame: frame, encoder: encoder, streamIndex: videoStreamIndex)
    }

    /// Encodes and writes an audio frame.
    public func writeAudioFrame(_ frame: borrowing Frame) throws {
        guard let encoder = audioEncoderContext else {
            throw FFmpegError.encoderNotFound
        }
        try encodeAndWrite(frame: frame, encoder: encoder, streamIndex: audioStreamIndex)
    }

    /// Flushes all encoders and writes the trailer.
    public func finish() throws {
        // Flush video encoder
        if let encoder = videoEncoderContext {
            try flushEncoder(encoder, streamIndex: videoStreamIndex)
        }
        // Flush audio encoder
        if let encoder = audioEncoderContext {
            try flushEncoder(encoder, streamIndex: audioStreamIndex)
        }

        if headerWritten {
            try formatContext.writeTrailer()
        }
    }

    private func encodeAndWrite(frame: borrowing Frame, encoder: CodecContext, streamIndex: Int32) throws {
        _ = try encoder.sendFrame(frame)
        try drainEncoder(encoder, streamIndex: streamIndex)
    }

    private func flushEncoder(_ encoder: CodecContext, streamIndex: Int32) throws {
        _ = try encoder.sendFlushFrame()
        try drainEncoder(encoder, streamIndex: streamIndex)
    }

    private func drainEncoder(_ encoder: CodecContext, streamIndex: Int32) throws {
        var packet = Packet()
        while true {
            let result = try encoder.receivePacket(into: &packet)
            if result != .success { break }

            packet.streamIndex = streamIndex

            let streamTimeBase = Rational(formatContext.pointer.pointee.streams[Int(streamIndex)]!.pointee.time_base)
            packet.rescaleTimestamps(from: encoder.timeBase, to: streamTimeBase)

            try formatContext.writeInterleavedFrame(packet: &packet)
            packet.unref()
        }
    }
}
