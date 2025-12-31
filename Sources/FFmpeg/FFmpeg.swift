// FFmpeg Swift Bindings
// Swift 6.2+ wrapper for FFmpeg libraries

#if canImport(CFFmpeg)
// System library configuration
@_exported import CFFmpeg
#else
// Artifact bundle configuration - import individual modules
@_exported import Clibavcodec
@_exported import Clibavformat
@_exported import Clibavutil
@_exported import Clibswscale
@_exported import Clibswresample
#endif

/// FFmpeg version information
public struct FFmpegVersion: Sendable {
    /// Get the libavcodec version
    public static var avcodec: String {
        let version = avcodec_version()
        let major = (version >> 16) & 0xFF
        let minor = (version >> 8) & 0xFF
        let micro = version & 0xFF
        return "\(major).\(minor).\(micro)"
    }

    /// Get the libavformat version
    public static var avformat: String {
        let version = avformat_version()
        let major = (version >> 16) & 0xFF
        let minor = (version >> 8) & 0xFF
        let micro = version & 0xFF
        return "\(major).\(minor).\(micro)"
    }

    /// Get the libavutil version
    public static var avutil: String {
        let version = avutil_version()
        let major = (version >> 16) & 0xFF
        let minor = (version >> 8) & 0xFF
        let micro = version & 0xFF
        return "\(major).\(minor).\(micro)"
    }

    /// Get the libswscale version
    public static var swscale: String {
        let version = swscale_version()
        let major = (version >> 16) & 0xFF
        let minor = (version >> 8) & 0xFF
        let micro = version & 0xFF
        return "\(major).\(minor).\(micro)"
    }

    /// Get the libswresample version
    public static var swresample: String {
        let version = swresample_version()
        let major = (version >> 16) & 0xFF
        let minor = (version >> 8) & 0xFF
        let micro = version & 0xFF
        return "\(major).\(minor).\(micro)"
    }

    /// Get the FFmpeg build configuration
    public static var configuration: String {
        String(cString: avcodec_configuration())
    }

    /// Get the FFmpeg license
    public static var license: String {
        String(cString: avcodec_license())
    }
}
