import CFFmpegShim

/// The result of a decode or encode operation.
public enum CodecResult: Sendable {
    /// A frame/packet was successfully produced.
    case success
    /// The codec needs more input before it can produce output.
    case needsMoreInput
    /// End of stream reached.
    case endOfFile
}

/// Wraps `AVCodecContext` for encoding and decoding.
public final class CodecContext: @unchecked Sendable {
    /// The underlying `AVCodecContext` pointer.
    public let pointer: UnsafeMutablePointer<AVCodecContext>

    /// Allocates a codec context for the given codec.
    public init(codec: UnsafePointer<AVCodec>) throws {
        guard let ctx = avcodec_alloc_context3(codec) else {
            throw FFmpegError.noMemory
        }
        self.pointer = ctx
    }

    deinit {
        var p: UnsafeMutablePointer<AVCodecContext>? = pointer
        avcodec_free_context(&p)
    }

    // MARK: - Configuration

    /// Copies parameters from `AVCodecParameters` into this context.
    public func setParameters(from params: UnsafeMutablePointer<AVCodecParameters>) throws {
        try ffCheck(avcodec_parameters_to_context(pointer, params))
    }

    /// Copies this context's parameters to an `AVCodecParameters`.
    public func copyParameters(to params: UnsafeMutablePointer<AVCodecParameters>) throws {
        try ffCheck(avcodec_parameters_from_context(params, pointer))
    }

    /// Opens the codec. Call after configuring all parameters.
    public func open(options: AVDictionaryWrapper? = nil) throws {
        var opts = options?.pointer
        try ffCheck(avcodec_open2(pointer, pointer.pointee.codec, &opts))
    }

    // MARK: - Properties

    /// Video width in pixels.
    public var width: Int32 {
        get { pointer.pointee.width }
        set { pointer.pointee.width = newValue }
    }

    /// Video height in pixels.
    public var height: Int32 {
        get { pointer.pointee.height }
        set { pointer.pointee.height = newValue }
    }

    /// Pixel format for video.
    public var pixelFormat: AVPixelFormat {
        get { pointer.pointee.pix_fmt }
        set { pointer.pointee.pix_fmt = newValue }
    }

    /// Sample format for audio.
    public var sampleFormat: AVSampleFormat {
        get { pointer.pointee.sample_fmt }
        set { pointer.pointee.sample_fmt = newValue }
    }

    /// Audio sample rate in Hz.
    public var sampleRate: Int32 {
        get { pointer.pointee.sample_rate }
        set { pointer.pointee.sample_rate = newValue }
    }

    /// Time base for the codec context.
    public var timeBase: Rational {
        get { Rational(pointer.pointee.time_base) }
        set { pointer.pointee.time_base = newValue.avRational }
    }

    /// Frame rate for video codecs.
    public var frameRate: Rational {
        get { Rational(pointer.pointee.framerate) }
        set { pointer.pointee.framerate = newValue.avRational }
    }

    /// Target bit rate.
    public var bitRate: Int64 {
        get { pointer.pointee.bit_rate }
        set { pointer.pointee.bit_rate = newValue }
    }

    /// Group-of-pictures size for video encoders.
    public var gopSize: Int32 {
        get { pointer.pointee.gop_size }
        set { pointer.pointee.gop_size = newValue }
    }

    /// Maximum number of B-frames.
    public var maxBFrames: Int32 {
        get { pointer.pointee.max_b_frames }
        set { pointer.pointee.max_b_frames = newValue }
    }

    /// Codec flags bitfield.
    public var flags: Int32 {
        get { pointer.pointee.flags }
        set { pointer.pointee.flags = newValue }
    }

    /// Media type of the codec.
    public var codecType: AVMediaType {
        pointer.pointee.codec_type
    }

    /// Audio channel layout.
    public var channelLayout: AVChannelLayout {
        get { pointer.pointee.ch_layout }
        set { pointer.pointee.ch_layout = newValue }
    }

    // MARK: - Decode

    /// Sends a packet to the decoder.
    public func sendPacket(_ packet: borrowing Packet) throws -> CodecResult {
        let ret = avcodec_send_packet(pointer, packet.pointer)
        if ret == cffmpeg_AVERROR_EAGAIN() { return .needsMoreInput }
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }

    /// Sends a flush signal (nil packet) to the decoder.
    public func sendFlush() throws -> CodecResult {
        let ret = avcodec_send_packet(pointer, nil)
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }

    /// Receives a decoded frame.
    public func receiveFrame(into frame: inout Frame) throws -> CodecResult {
        let ret = avcodec_receive_frame(pointer, frame.pointer)
        if ret == cffmpeg_AVERROR_EAGAIN() { return .needsMoreInput }
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }

    // MARK: - Encode

    /// Sends a frame to the encoder.
    public func sendFrame(_ frame: borrowing Frame) throws -> CodecResult {
        let ret = avcodec_send_frame(pointer, frame.pointer)
        if ret == cffmpeg_AVERROR_EAGAIN() { return .needsMoreInput }
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }

    /// Sends a flush signal (nil frame) to the encoder.
    public func sendFlushFrame() throws -> CodecResult {
        let ret = avcodec_send_frame(pointer, nil)
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }

    /// Receives an encoded packet.
    public func receivePacket(into packet: inout Packet) throws -> CodecResult {
        let ret = avcodec_receive_packet(pointer, packet.pointer)
        if ret == cffmpeg_AVERROR_EAGAIN() { return .needsMoreInput }
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }

    /// Flushes the codec buffers.
    public func flush() {
        avcodec_flush_buffers(pointer)
    }
}
