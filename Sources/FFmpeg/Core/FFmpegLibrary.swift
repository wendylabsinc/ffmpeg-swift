import CFFmpegShim

/// Provides version and initialization utilities for FFmpeg.
public enum FFmpegLibrary {
    /// Returns the libavutil version as a human-readable string.
    public static var avutilVersion: String {
        String(cString: av_version_info())
    }

    /// Returns the libavcodec build-time version number.
    public static var avcodecVersion: UInt32 {
        avcodec_version()
    }

    /// Returns the libavformat build-time version number.
    public static var avformatVersion: UInt32 {
        avformat_version()
    }

    /// Sets the FFmpeg log level.
    public static func setLogLevel(_ level: LogLevel) {
        av_log_set_level(level.rawValue)
    }

    /// FFmpeg log levels.
    public enum LogLevel: Int32, Sendable {
        case quiet   = -8
        case panic   = 0
        case fatal   = 8
        case error   = 16
        case warning = 24
        case info    = 32
        case verbose = 40
        case debug   = 48
    }
}
