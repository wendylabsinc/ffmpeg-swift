import CFFmpegShim

/// A copyable, reference-counted wrapper around `AVFrame*` for use with async streams.
///
/// Since `Frame` is `~Copyable`, it cannot be used as the element type of `AsyncThrowingStream`.
/// `OwnedFrame` provides a class-based wrapper that can be passed through async boundaries.
public final class OwnedFrame: @unchecked Sendable {
    /// The underlying `AVFrame` pointer.
    public let pointer: UnsafeMutablePointer<AVFrame>

    init(movingFrom frame: inout Frame) {
        let newPtr = av_frame_alloc()!
        av_frame_move_ref(newPtr, frame.pointer)
        self.pointer = newPtr
    }

    deinit {
        var p: UnsafeMutablePointer<AVFrame>? = pointer
        av_frame_free(&p)
    }

    /// Video width in pixels.
    public var width: Int32 { pointer.pointee.width }
    /// Video height in pixels.
    public var height: Int32 { pointer.pointee.height }
    /// Presentation timestamp.
    public var pts: Int64 { pointer.pointee.pts }
    /// Frame duration in time base units.
    public var duration: Int64 { pointer.pointee.duration }

    /// Pixel format for video.
    public var pixelFormat: PixelFormat {
        PixelFormat(rawValue: pointer.pointee.format)
    }

    /// Sample format for audio.
    public var sampleFormat: SampleFormat {
        SampleFormat(rawValue: pointer.pointee.format)
    }

    /// Audio sample rate in Hz.
    public var sampleRate: Int32 { pointer.pointee.sample_rate }
    /// Audio channel layout.
    public var channelLayout: ChannelLayout {
        ChannelLayout(pointer.pointee.ch_layout)
    }
    /// Number of audio samples per channel.
    public var numberOfSamples: Int32 { pointer.pointee.nb_samples }

    /// Time base associated with `pts`/`duration`.
    public var timeBase: Rational {
        Rational(pointer.pointee.time_base)
    }

    /// Takes ownership of the underlying frame data into a move-only `Frame`.
    /// After this call, this `OwnedFrame`'s data is unrefed.
    public func takeFrame() -> Frame {
        let f = Frame()
        av_frame_move_ref(f.pointer, pointer)
        return f
    }
}

/// High-level media file reader that provides decoded frames as `AsyncThrowingStream`.
public final class MediaReader: @unchecked Sendable {
    /// The underlying input format context.
    public let formatContext: FormatContext

    private var videoDecoderContext: CodecContext?
    private var audioDecoderContext: CodecContext?

    /// Video stream index in the input, or `-1` if not present.
    public private(set) var videoStreamIndex: Int32 = -1
    /// Audio stream index in the input, or `-1` if not present.
    public private(set) var audioStreamIndex: Int32 = -1

    /// Opens a media file and auto-discovers video/audio streams.
    public init(url: String) throws {
        self.formatContext = try FormatContext.openInput(url: url)

        // Try to find and set up video decoder
        if let videoIdx = try? formatContext.findBestStream(type: .video) {
            self.videoStreamIndex = videoIdx
            let stream = formatContext.stream(at: Int(videoIdx))
            let codec = try Codec.findDecoder(id: stream.codecID)
            let ctx = try CodecContext(codec: codec)
            try ctx.setParameters(from: stream.codecParameters)
            ctx.timeBase = stream.timeBase
            try ctx.open()
            self.videoDecoderContext = ctx
        }

        // Try to find and set up audio decoder
        if let audioIdx = try? formatContext.findBestStream(type: .audio) {
            self.audioStreamIndex = audioIdx
            let stream = formatContext.stream(at: Int(audioIdx))
            let codec = try Codec.findDecoder(id: stream.codecID)
            let ctx = try CodecContext(codec: codec)
            try ctx.setParameters(from: stream.codecParameters)
            ctx.timeBase = stream.timeBase
            try ctx.open()
            self.audioDecoderContext = ctx
        }
    }

    /// Stream metadata for all streams.
    public var streams: [StreamInfo] {
        formatContext.streams
    }

    /// Total duration in seconds, or `nil` if unknown.
    public var durationSeconds: Double? {
        formatContext.durationSeconds
    }

    /// Returns an `AsyncThrowingStream` of decoded video frames.
    public func videoFrames() -> AsyncThrowingStream<OwnedFrame, Error> {
        guard let decoder = videoDecoderContext else {
            return AsyncThrowingStream { $0.finish() }
        }
        return decodedFrames(streamIndex: videoStreamIndex, decoder: decoder)
    }

    /// Returns an `AsyncThrowingStream` of decoded audio frames.
    public func audioFrames() -> AsyncThrowingStream<OwnedFrame, Error> {
        guard let decoder = audioDecoderContext else {
            return AsyncThrowingStream { $0.finish() }
        }
        return decodedFrames(streamIndex: audioStreamIndex, decoder: decoder)
    }

    private func decodedFrames(streamIndex: Int32, decoder: CodecContext) -> AsyncThrowingStream<OwnedFrame, Error> {
        AsyncThrowingStream { continuation in
            do {
                var packet = Packet()
                var frame = Frame()

                while try formatContext.readFrame(into: &packet) {
                    defer { packet.unref() }

                    guard packet.streamIndex == streamIndex else { continue }

                    let sendResult = try decoder.sendPacket(packet)
                    if sendResult == .endOfFile { break }

                    while true {
                        frame.unref()
                        let recvResult = try decoder.receiveFrame(into: &frame)
                        switch recvResult {
                        case .success:
                            let owned = OwnedFrame(movingFrom: &frame)
                            continuation.yield(owned)
                        case .needsMoreInput:
                            break
                        case .endOfFile:
                            break
                        }
                        if recvResult != .success { break }
                    }
                }

                // Flush decoder
                _ = try decoder.sendFlush()
                while true {
                    frame.unref()
                    let recvResult = try decoder.receiveFrame(into: &frame)
                    if recvResult != .success { break }
                    let owned = OwnedFrame(movingFrom: &frame)
                    continuation.yield(owned)
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
