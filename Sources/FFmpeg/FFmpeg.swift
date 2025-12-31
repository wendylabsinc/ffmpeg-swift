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
public struct SemanticVersion: Sendable, Comparable, CustomStringConvertible {
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

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// Typealias for convenience
public typealias Version = SemanticVersion

// MARK: - FFmpeg

/// FFmpeg library information and utilities
public enum FFmpeg {
    /// Library versions
    public enum Versions {
        public static var avcodec: SemanticVersion {
            .init(packed: avcodec_version())
        }

        public static var avformat: SemanticVersion {
            .init(packed: avformat_version())
        }

        public static var avutil: SemanticVersion {
            .init(packed: avutil_version())
        }

        public static var swscale: SemanticVersion {
            .init(packed: swscale_version())
        }

        public static var swresample: SemanticVersion {
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

/// Compute AVERROR tag from 4 characters (matches FFmpeg's FFERRTAG macro)
@inlinable
public func AVERROR_TAG(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> Int32 {
    -Int32(bitPattern: UInt32(a) | (UInt32(b) << 8) | (UInt32(c) << 16) | (UInt32(d) << 24))
}

/// Common FFmpeg error codes
public let AVERROR_EOF = AVERROR_TAG(0x45, 0x4F, 0x46, 0x20)  // 'E','O','F',' '
public let AVERROR_INVALIDDATA = AVERROR_TAG(0x49, 0x4E, 0x44, 0x41)  // 'I','N','D','A'
public let AVERROR_DECODER_NOT_FOUND = AVERROR_TAG(0xF8, 0x44, 0x45, 0x43)  // 0xF8,'D','E','C'
public let AVERROR_ENCODER_NOT_FOUND = AVERROR_TAG(0xF8, 0x45, 0x4E, 0x43)  // 0xF8,'E','N','C'
public let AVERROR_DEMUXER_NOT_FOUND = AVERROR_TAG(0xF8, 0x44, 0x45, 0x4D)  // 0xF8,'D','E','M'
public let AVERROR_MUXER_NOT_FOUND = AVERROR_TAG(0xF8, 0x4D, 0x55, 0x58)  // 0xF8,'M','U','X'

extension FFmpegError {
    public static var endOfFile: Int32 { AVERROR_EOF }
    public static var invalidData: Int32 { AVERROR_INVALIDDATA }
}

// MARK: - Codec

/// Swift wrapper for AVCodec
public struct Codec: @unchecked Sendable {
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

/// Deprecated: Use `FFmpeg.Versions` instead
@available(*, deprecated, renamed: "FFmpeg.Versions")
public typealias FFmpegVersion = _FFmpegVersionCompat

public enum _FFmpegVersionCompat {
    public static var avcodec: String { FFmpeg.Versions.avcodec.description }
    public static var avformat: String { FFmpeg.Versions.avformat.description }
    public static var avutil: String { FFmpeg.Versions.avutil.description }
    public static var swscale: String { FFmpeg.Versions.swscale.description }
    public static var swresample: String { FFmpeg.Versions.swresample.description }
    public static var configuration: String { FFmpeg.configuration }
    public static var license: String { FFmpeg.license }
}
