import CFFmpegShim

/// A read-only view of an `AVStream`'s metadata.
public struct StreamInfo: @unchecked Sendable {
    /// Stream index.
    public let index: Int32
    /// Media type (video/audio/subtitle).
    public let mediaType: MediaType
    /// Codec ID for the stream.
    public let codecID: CodecID
    /// Underlying codec parameters pointer.
    internal let codecParameters: UnsafeMutablePointer<AVCodecParameters>
    /// Stream time base.
    public let timeBase: Rational
    /// Stream duration in time base units.
    public let duration: Int64
    /// Number of frames if known.
    public let numberOfFrames: Int64
    /// Stream start time in time base units.
    public let startTime: Int64
    /// Average frame rate.
    public let averageFrameRate: Rational
    /// Real frame rate.
    public let realFrameRate: Rational

    init(stream: UnsafeMutablePointer<AVStream>) {
        let s = stream.pointee
        self.index = Int32(s.index)
        self.mediaType = MediaType(rawValue: s.codecpar.pointee.codec_type.rawValue)
        self.codecID = CodecID(rawValue: s.codecpar.pointee.codec_id.rawValue)
        self.codecParameters = s.codecpar
        self.timeBase = Rational(s.time_base)
        self.duration = s.duration
        self.numberOfFrames = s.nb_frames
        self.startTime = s.start_time
        self.averageFrameRate = Rational(s.avg_frame_rate)
        self.realFrameRate = Rational(s.r_frame_rate)
    }

    /// Whether this is a video stream.
    public var isVideo: Bool {
        mediaType == .video
    }

    /// Whether this is an audio stream.
    public var isAudio: Bool {
        mediaType == .audio
    }

    /// Whether this is a subtitle stream.
    public var isSubtitle: Bool {
        mediaType == .subtitle
    }

    /// Duration in seconds (using the stream's time base).
    public var durationSeconds: Double {
        guard duration != cffmpeg_AV_NOPTS_VALUE else { return 0 }
        return Double(duration) * timeBase.doubleValue
    }

    /// Creates and opens a decoder context for this stream.
    public func makeDecoderContext() throws -> CodecContext {
        let codec = try Codec.findDecoder(id: codecID)
        let ctx = try CodecContext(codec: codec)
        try ctx.setParameters(from: codecParameters)
        try ctx.open()
        return ctx
    }
}
