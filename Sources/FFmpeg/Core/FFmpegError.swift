import CFFmpegShim

/// A type-safe wrapper around FFmpeg's integer error codes.
public struct FFmpegError: Error, Sendable, Equatable, CustomStringConvertible {
    public let code: Int32

    public init(code: Int32) {
        self.code = code
    }

    public var description: String {
        String(cString: cffmpeg_av_err2str(code))
    }

    // MARK: - Well-known errors

    public static let eof = FFmpegError(code: cffmpeg_AVERROR_EOF())
    public static let eagain = FFmpegError(code: cffmpeg_AVERROR_EAGAIN())
    public static let invalidData = FFmpegError(code: cffmpeg_AVERROR_INVALIDDATA)
    public static let decoderNotFound = FFmpegError(code: cffmpeg_AVERROR_DECODER_NOT_FOUND)
    public static let encoderNotFound = FFmpegError(code: cffmpeg_AVERROR_ENCODER_NOT_FOUND)
    public static let demuxerNotFound = FFmpegError(code: cffmpeg_AVERROR_DEMUXER_NOT_FOUND)
    public static let muxerNotFound = FFmpegError(code: cffmpeg_AVERROR_MUXER_NOT_FOUND)
    public static let filterNotFound = FFmpegError(code: cffmpeg_AVERROR_FILTER_NOT_FOUND)
    public static let streamNotFound = FFmpegError(code: cffmpeg_AVERROR_STREAM_NOT_FOUND)
    public static let protocolNotFound = FFmpegError(code: cffmpeg_AVERROR_PROTOCOL_NOT_FOUND)
    public static let optionNotFound = FFmpegError(code: cffmpeg_AVERROR_OPTION_NOT_FOUND)
    public static let bug = FFmpegError(code: cffmpeg_AVERROR_BUG)
    public static let noMemory = FFmpegError(code: cffmpeg_AVERROR_ENOMEM())
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
