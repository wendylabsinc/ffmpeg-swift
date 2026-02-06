import CFFmpegShim

/// A move-only wrapper around `AVPacket*`.
///
/// Owns the underlying packet and frees it on `deinit`.
public struct Packet: ~Copyable {
    public var pointer: UnsafeMutablePointer<AVPacket>

    /// Allocates a new empty `AVPacket`.
    public init() {
        guard let ptr = av_packet_alloc() else {
            fatalError("av_packet_alloc returned nil")
        }
        self.pointer = ptr
    }

    /// Takes ownership of an existing `AVPacket*`.
    public init(takingOwnershipOf ptr: UnsafeMutablePointer<AVPacket>) {
        self.pointer = ptr
    }

    deinit {
        var p: UnsafeMutablePointer<AVPacket>? = pointer
        av_packet_free(&p)
    }

    // MARK: - Properties

    public var streamIndex: Int32 {
        get { pointer.pointee.stream_index }
        set { pointer.pointee.stream_index = newValue }
    }

    public var pts: Int64 {
        get { pointer.pointee.pts }
        set { pointer.pointee.pts = newValue }
    }

    public var dts: Int64 {
        get { pointer.pointee.dts }
        set { pointer.pointee.dts = newValue }
    }

    public var duration: Int64 {
        get { pointer.pointee.duration }
        set { pointer.pointee.duration = newValue }
    }

    public var size: Int32 {
        pointer.pointee.size
    }

    public var data: UnsafeMutablePointer<UInt8>? {
        pointer.pointee.data
    }

    public var flags: Int32 {
        get { pointer.pointee.flags }
        set { pointer.pointee.flags = newValue }
    }

    public var isKeyFrame: Bool {
        (flags & cffmpeg_AV_PKT_FLAG_KEY) != 0
    }

    /// Unreference the packet data, resetting it to an empty state.
    public mutating func unref() {
        av_packet_unref(pointer)
    }

    /// Rescale timestamps from one time base to another.
    public mutating func rescaleTimestamps(from src: Rational, to dst: Rational) {
        av_packet_rescale_ts(pointer, src.avRational, dst.avRational)
    }
}
