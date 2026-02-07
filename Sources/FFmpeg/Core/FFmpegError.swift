import CFFmpegShim

/// A type-safe wrapper around FFmpeg's integer error codes.
public struct FFmpegError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The raw FFmpeg error code.
    public let code: Int32

    /// Creates an error from a raw FFmpeg error code.
    public init(code: Int32) {
        self.code = code
    }

    /// A human-readable error string from FFmpeg.
    public var description: String {
        String(cString: cffmpeg_av_err2str(code))
    }

    // MARK: - Well-known errors

    /// End-of-file.
    public static let eof = FFmpegError(code: cffmpeg_AVERROR_EOF())
    /// Try again (EAGAIN).
    public static let eagain = FFmpegError(code: cffmpeg_AVERROR_EAGAIN())
    /// Invalid data.
    public static let invalidData = FFmpegError(code: cffmpeg_AVERROR_INVALIDDATA)
    /// Decoder not found.
    public static let decoderNotFound = FFmpegError(code: cffmpeg_AVERROR_DECODER_NOT_FOUND)
    /// Encoder not found.
    public static let encoderNotFound = FFmpegError(code: cffmpeg_AVERROR_ENCODER_NOT_FOUND)
    /// Demuxer not found.
    public static let demuxerNotFound = FFmpegError(code: cffmpeg_AVERROR_DEMUXER_NOT_FOUND)
    /// Muxer not found.
    public static let muxerNotFound = FFmpegError(code: cffmpeg_AVERROR_MUXER_NOT_FOUND)
    /// Filter not found.
    public static let filterNotFound = FFmpegError(code: cffmpeg_AVERROR_FILTER_NOT_FOUND)
    /// Stream not found.
    public static let streamNotFound = FFmpegError(code: cffmpeg_AVERROR_STREAM_NOT_FOUND)
    /// Protocol not found.
    public static let protocolNotFound = FFmpegError(code: cffmpeg_AVERROR_PROTOCOL_NOT_FOUND)
    /// Option not found.
    public static let optionNotFound = FFmpegError(code: cffmpeg_AVERROR_OPTION_NOT_FOUND)
    /// Internal bug.
    public static let bug = FFmpegError(code: cffmpeg_AVERROR_BUG)
    /// Out of memory.
    public static let noMemory = FFmpegError(code: cffmpeg_AVERROR_ENOMEM())
    /// Unknown error.
    public static let unknown = FFmpegError(code: cffmpeg_AVERROR_UNKNOWN)
}

/// Checks an FFmpeg return code and throws `FFmpegError` if negative.
@discardableResult
public func ffCheck(_ code: Int32) throws -> Int32 {
    if code < 0 {
        throw FFmpegError(code: code)
    }
    return code
}
