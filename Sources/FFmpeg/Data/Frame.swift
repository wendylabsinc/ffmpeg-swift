import CFFmpegShim

/// A move-only wrapper around `AVFrame*`.
///
/// Owns the underlying frame and frees it on `deinit`.
/// Use `borrowing` access to pass frames to FFmpeg functions without transferring ownership.
public struct Frame: ~Copyable {
    /// The underlying `AVFrame` pointer.
    public var pointer: UnsafeMutablePointer<AVFrame>

    /// Allocates a new empty `AVFrame`.
    public init() {
        guard let ptr = av_frame_alloc() else {
            fatalError("av_frame_alloc returned nil")
        }
        self.pointer = ptr
    }

    /// Takes ownership of an existing `AVFrame*`.
    public init(takingOwnershipOf ptr: UnsafeMutablePointer<AVFrame>) {
        self.pointer = ptr
    }

    deinit {
        var p: UnsafeMutablePointer<AVFrame>? = pointer
        av_frame_free(&p)
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
    public var pixelFormat: PixelFormat {
        get { PixelFormat(rawValue: pointer.pointee.format) }
        set { pointer.pointee.format = newValue.rawValue }
    }

    /// Sample format for audio.
    public var sampleFormat: SampleFormat {
        get { SampleFormat(rawValue: pointer.pointee.format) }
        set { pointer.pointee.format = newValue.rawValue }
    }

    /// Audio sample rate in Hz.
    public var sampleRate: Int32 {
        get { pointer.pointee.sample_rate }
        set { pointer.pointee.sample_rate = newValue }
    }

    /// Number of audio samples per channel.
    public var numberOfSamples: Int32 {
        get { pointer.pointee.nb_samples }
        set { pointer.pointee.nb_samples = newValue }
    }

    /// Presentation timestamp.
    public var pts: Int64 {
        get { pointer.pointee.pts }
        set { pointer.pointee.pts = newValue }
    }

    /// Frame duration in time base units.
    public var duration: Int64 {
        get { pointer.pointee.duration }
        set { pointer.pointee.duration = newValue }
    }

    /// Time base associated with `pts`/`duration`.
    public var timeBase: Rational {
        get { Rational(pointer.pointee.time_base) }
        set { pointer.pointee.time_base = newValue.avRational }
    }

    /// Whether this frame is a key frame.
    public var isKeyFrame: Bool {
        (pointer.pointee.flags & AV_FRAME_FLAG_KEY) != 0
    }

    /// Access the data pointer for a given plane index.
    public func dataPointer(plane: Int) -> UnsafeMutablePointer<UInt8>? {
        withUnsafePointer(to: pointer.pointee.data) { tuplePtr in
            tupleElement(tuplePtr, index: plane, as: UnsafeMutablePointer<UInt8>?.self)
        }
    }

    /// Access the linesize for a given plane index.
    public func linesize(plane: Int) -> Int32 {
        withUnsafePointer(to: pointer.pointee.linesize) { tuplePtr in
            tupleElement(tuplePtr, index: plane, as: Int32.self)
        }
    }

    /// Allocate buffers for the frame based on its format and dimensions.
    public mutating func allocateBuffers(align: Int32 = 0) throws {
        try ffCheck(av_frame_get_buffer(pointer, align))
    }

    /// Make the frame data writable (copy-on-write if shared).
    public mutating func makeWritable() throws {
        try ffCheck(av_frame_make_writable(pointer))
    }

    /// Unreference all buffers and reset fields.
    public mutating func unref() {
        av_frame_unref(pointer)
    }

    /// Copy properties from another frame (timestamps, etc.), not data.
    public mutating func copyProperties(from source: borrowing Frame) throws {
        try ffCheck(av_frame_copy_props(pointer, source.pointer))
    }
}
