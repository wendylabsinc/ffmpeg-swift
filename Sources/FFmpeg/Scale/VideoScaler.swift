import CFFmpegShim

/// A move-only wrapper around `SwsContext` for video pixel format conversion and scaling.
public struct VideoScaler: ~Copyable {
    private var context: OpaquePointer

    /// Creates a video scaler.
    ///
    /// - Parameters:
    ///   - srcWidth: Source width in pixels.
    ///   - srcHeight: Source height in pixels.
    ///   - srcFormat: Source pixel format.
    ///   - dstWidth: Destination width in pixels.
    ///   - dstHeight: Destination height in pixels.
    ///   - dstFormat: Destination pixel format.
    ///   - flags: Scaling algorithm (default: bilinear).
    public init(
        srcWidth: Int32, srcHeight: Int32, srcFormat: PixelFormat,
        dstWidth: Int32, dstHeight: Int32, dstFormat: PixelFormat,
        flags: Int32 = SWS_BILINEAR
    ) throws {
        guard let ctx = sws_getContext(
            srcWidth, srcHeight, srcFormat.avValue,
            dstWidth, dstHeight, dstFormat.avValue,
            flags, nil, nil, nil
        ) else {
            throw FFmpegError.unknown
        }
        self.context = ctx
    }

    deinit {
        sws_freeContext(context)
    }

    /// Scales/converts pixels from `source` frame into `destination` frame using `sws_scale_frame`.
    ///
    /// Both frames must have their dimensions/formats set. Destination buffers will be allocated
    /// automatically by `sws_scale_frame` if not already allocated.
    public func scale(source: borrowing Frame, into destination: inout Frame) throws {
        try ffCheck(sws_scale_frame(context, destination.pointer, source.pointer))
    }
}
