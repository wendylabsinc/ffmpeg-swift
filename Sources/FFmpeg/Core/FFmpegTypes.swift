import CFFmpegShim

/// High-level media type used throughout the Swift API.
public struct MediaType: RawRepresentable, Sendable, Hashable, CustomStringConvertible {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let unknown = MediaType(rawValue: AVMEDIA_TYPE_UNKNOWN.rawValue)
    public static let video = MediaType(rawValue: AVMEDIA_TYPE_VIDEO.rawValue)
    public static let audio = MediaType(rawValue: AVMEDIA_TYPE_AUDIO.rawValue)
    public static let subtitle = MediaType(rawValue: AVMEDIA_TYPE_SUBTITLE.rawValue)
    public static let data = MediaType(rawValue: AVMEDIA_TYPE_DATA.rawValue)
    public static let attachment = MediaType(rawValue: AVMEDIA_TYPE_ATTACHMENT.rawValue)

    public var description: String {
        switch rawValue {
        case MediaType.video.rawValue: return "video"
        case MediaType.audio.rawValue: return "audio"
        case MediaType.subtitle.rawValue: return "subtitle"
        case MediaType.data.rawValue: return "data"
        case MediaType.attachment.rawValue: return "attachment"
        default: return "unknown(\(rawValue))"
        }
    }

    internal var avValue: AVMediaType {
        AVMediaType(rawValue: rawValue) ?? AVMEDIA_TYPE_UNKNOWN
    }
}

/// High-level codec identifier used throughout the Swift API.
public struct CodecID: RawRepresentable, Sendable, Hashable, CustomStringConvertible {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none = CodecID(rawValue: AV_CODEC_ID_NONE.rawValue)
    public static let h264 = CodecID(rawValue: AV_CODEC_ID_H264.rawValue)
    public static let hevc = CodecID(rawValue: AV_CODEC_ID_HEVC.rawValue)
    public static let aac = CodecID(rawValue: AV_CODEC_ID_AAC.rawValue)
    public static let mp3 = CodecID(rawValue: AV_CODEC_ID_MP3.rawValue)

    public var description: String {
        let name = avcodec_get_name(avValue)
        return String(cString: name)
    }

    internal var avValue: AVCodecID {
        AVCodecID(rawValue: rawValue) ?? AV_CODEC_ID_NONE
    }
}

/// High-level pixel format used throughout the Swift API.
public struct PixelFormat: RawRepresentable, Sendable, Hashable, CustomStringConvertible {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none = PixelFormat(rawValue: AV_PIX_FMT_NONE.rawValue)
    public static let yuv420p = PixelFormat(rawValue: AV_PIX_FMT_YUV420P.rawValue)
    public static let nv12 = PixelFormat(rawValue: AV_PIX_FMT_NV12.rawValue)
    public static let rgb24 = PixelFormat(rawValue: AV_PIX_FMT_RGB24.rawValue)
    public static let rgba = PixelFormat(rawValue: AV_PIX_FMT_RGBA.rawValue)
    public static let bgra = PixelFormat(rawValue: AV_PIX_FMT_BGRA.rawValue)

    public var description: String {
        guard let ptr = av_get_pix_fmt_name(avValue) else {
            return "unknown(\(rawValue))"
        }
        return String(cString: ptr)
    }

    internal var avValue: AVPixelFormat {
        AVPixelFormat(rawValue: rawValue) ?? AV_PIX_FMT_NONE
    }
}

/// High-level audio sample format used throughout the Swift API.
public struct SampleFormat: RawRepresentable, Sendable, Hashable, CustomStringConvertible {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none = SampleFormat(rawValue: AV_SAMPLE_FMT_NONE.rawValue)
    public static let s16 = SampleFormat(rawValue: AV_SAMPLE_FMT_S16.rawValue)
    public static let s16p = SampleFormat(rawValue: AV_SAMPLE_FMT_S16P.rawValue)
    public static let flt = SampleFormat(rawValue: AV_SAMPLE_FMT_FLT.rawValue)
    public static let fltp = SampleFormat(rawValue: AV_SAMPLE_FMT_FLTP.rawValue)

    public var description: String {
        guard let ptr = av_get_sample_fmt_name(avValue) else {
            return "unknown(\(rawValue))"
        }
        return String(cString: ptr)
    }

    internal var avValue: AVSampleFormat {
        AVSampleFormat(rawValue: rawValue) ?? AV_SAMPLE_FMT_NONE
    }
}

/// High-level audio channel layout used throughout the Swift API.
public struct ChannelLayout: Sendable, CustomStringConvertible {
    internal var layout: AVChannelLayout

    /// Creates a default layout for the given channel count.
    public init(channels: Int32) {
        var l = AVChannelLayout()
        av_channel_layout_default(&l, channels)
        self.layout = l
    }

    /// Mono layout (1 channel).
    public static let mono = ChannelLayout(channels: 1)
    /// Stereo layout (2 channels).
    public static let stereo = ChannelLayout(channels: 2)

    /// Number of channels in the layout.
    public var channelCount: Int32 {
        layout.nb_channels
    }

    public var description: String {
        var buffer = [CChar](repeating: 0, count: 128)
        _ = av_channel_layout_describe(&layout, &buffer, buffer.count)
        return String(cString: buffer)
    }

    internal init(_ layout: AVChannelLayout) {
        self.layout = layout
    }

    internal var avValue: AVChannelLayout {
        layout
    }
}

/// Opaque handle to an FFmpeg codec.
public struct CodecRef: Sendable {
    internal let pointer: UnsafePointer<AVCodec>

    internal init(_ pointer: UnsafePointer<AVCodec>) {
        self.pointer = pointer
    }
}

/// Opaque handle to an FFmpeg stream.
public struct StreamHandle: Sendable {
    internal let pointer: UnsafeMutablePointer<AVStream>

    internal init(_ pointer: UnsafeMutablePointer<AVStream>) {
        self.pointer = pointer
    }

    /// Stream index.
    public var index: Int32 {
        Int32(pointer.pointee.index)
    }

    /// Stream time base.
    public var timeBase: Rational {
        Rational(pointer.pointee.time_base)
    }
}
