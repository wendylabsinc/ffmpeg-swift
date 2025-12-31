// FFmpeg Swift Bindings
// Swift 6.2+ wrapper for FFmpeg libraries

#if canImport(CFFmpeg)
@_exported import CFFmpeg
#else
@_exported import Clibavcodec
@_exported import Clibavformat
@_exported import Clibavutil
@_exported import Clibswscale
@_exported import Clibswresample
#endif

// MARK: - Version

/// Semantic version representation
public struct Version: Sendable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Initialize from FFmpeg's packed version format
    public init(packed: UInt32) {
        self.major = Int((packed >> 16) & 0xFF)
        self.minor = Int((packed >> 8) & 0xFF)
        self.patch = Int(packed & 0xFF)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

// MARK: - FFmpeg

/// FFmpeg library information and utilities
public enum FFmpeg {
    /// Library versions
    public enum Version {
        public static var avcodec: FFmpeg_Swift.Version {
            .init(packed: avcodec_version())
        }

        public static var avformat: FFmpeg_Swift.Version {
            .init(packed: avformat_version())
        }

        public static var avutil: FFmpeg_Swift.Version {
            .init(packed: avutil_version())
        }

        public static var swscale: FFmpeg_Swift.Version {
            .init(packed: swscale_version())
        }

        public static var swresample: FFmpeg_Swift.Version {
            .init(packed: swresample_version())
        }
    }

    /// Build configuration string
    public static var configuration: String {
        String(cString: avcodec_configuration())
    }

    /// License type (e.g., "LGPL version 2.1 or later")
    public static var license: String {
        String(cString: avcodec_license())
    }
}

// MARK: - Error Handling

/// FFmpeg error codes wrapped as Swift errors
public struct FFmpegError: Error, CustomStringConvertible, Sendable {
    public let code: Int32
    public let message: String

    public init(code: Int32) {
        self.code = code
        var buffer = [CChar](repeating: 0, count: 256)
        av_strerror(code, &buffer, buffer.count)
        self.message = String(cString: buffer)
    }

    public var description: String {
        "FFmpegError(\(code)): \(message)"
    }

    /// Check if an FFmpeg return value indicates an error
    @inlinable
    public static func check(_ result: Int32) throws {
        if result < 0 {
            throw FFmpegError(code: result)
        }
    }
}

// MARK: - Common Error Codes

extension FFmpegError {
    public static var endOfFile: Int32 { AVERROR_EOF }
    public static var invalidData: Int32 { AVERROR_INVALIDDATA }
}

// MARK: - Codec

/// Swift wrapper for AVCodec
public struct Codec: Sendable {
    public let pointer: UnsafePointer<AVCodec>

    public init?(_ pointer: UnsafePointer<AVCodec>?) {
        guard let pointer else { return nil }
        self.pointer = pointer
    }

    public var name: String {
        String(cString: pointer.pointee.name)
    }

    public var longName: String {
        guard let longName = pointer.pointee.long_name else { return name }
        return String(cString: longName)
    }

    public var isEncoder: Bool {
        av_codec_is_encoder(pointer) != 0
    }

    public var isDecoder: Bool {
        av_codec_is_decoder(pointer) != 0
    }

    /// Find a decoder by codec ID
    public static func decoder(for codecID: AVCodecID) -> Codec? {
        Codec(avcodec_find_decoder(codecID))
    }

    /// Find an encoder by codec ID
    public static func encoder(for codecID: AVCodecID) -> Codec? {
        Codec(avcodec_find_encoder(codecID))
    }

    /// Find a decoder by name
    public static func decoder(named name: String) -> Codec? {
        Codec(avcodec_find_decoder_by_name(name))
    }

    /// Find an encoder by name
    public static func encoder(named name: String) -> Codec? {
        Codec(avcodec_find_encoder_by_name(name))
    }
}

// MARK: - Pixel Format

extension AVPixelFormat: @retroactive CustomStringConvertible {
    public var description: String {
        guard let name = av_get_pix_fmt_name(self) else { return "unknown" }
        return String(cString: name)
    }

    /// Get pixel format by name
    public static func named(_ name: String) -> AVPixelFormat {
        av_get_pix_fmt(name)
    }
}

// MARK: - Sample Format

extension AVSampleFormat: @retroactive CustomStringConvertible {
    public var description: String {
        guard let name = av_get_sample_fmt_name(self) else { return "unknown" }
        return String(cString: name)
    }

    /// Bytes per sample for this format
    public var bytesPerSample: Int {
        Int(av_get_bytes_per_sample(self))
    }

    /// Whether this is a planar format
    public var isPlanar: Bool {
        av_sample_fmt_is_planar(self) != 0
    }
}

// MARK: - Deprecated Compatibility

/// Deprecated: Use `FFmpeg.Version` instead
@available(*, deprecated, renamed: "FFmpeg.Version")
public typealias FFmpegVersion = _FFmpegVersionCompat

public enum _FFmpegVersionCompat {
    public static var avcodec: String { FFmpeg.Version.avcodec.description }
    public static var avformat: String { FFmpeg.Version.avformat.description }
    public static var avutil: String { FFmpeg.Version.avutil.description }
    public static var swscale: String { FFmpeg.Version.swscale.description }
    public static var swresample: String { FFmpeg.Version.swresample.description }
    public static var configuration: String { FFmpeg.configuration }
    public static var license: String { FFmpeg.license }
}
