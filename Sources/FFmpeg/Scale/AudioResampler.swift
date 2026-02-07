import CFFmpegShim

/// A move-only wrapper around `SwrContext` for audio resampling and format conversion.
public struct AudioResampler: ~Copyable {
    private var context: OpaquePointer

    /// Creates an audio resampler.
    ///
    /// - Parameters:
    ///   - srcChannelLayout: Source channel layout.
    ///   - srcSampleRate: Source sample rate in Hz.
    ///   - srcFormat: Source sample format.
    ///   - dstChannelLayout: Destination channel layout.
    ///   - dstSampleRate: Destination sample rate in Hz.
    ///   - dstFormat: Destination sample format.
    public init(
        srcChannelLayout: ChannelLayout,
        srcSampleRate: Int32,
        srcFormat: SampleFormat,
        dstChannelLayout: ChannelLayout,
        dstSampleRate: Int32,
        dstFormat: SampleFormat
    ) throws {
        var ctx: OpaquePointer? = nil
        var srcLayout = srcChannelLayout.avValue
        var dstLayout = dstChannelLayout.avValue

        // swr_alloc_set_opts2 expects UnsafeMutablePointer<OpaquePointer?> for the first arg
        let ret = swr_alloc_set_opts2(
            &ctx,
            &dstLayout, dstFormat.avValue, dstSampleRate,
            &srcLayout, srcFormat.avValue, srcSampleRate,
            0, nil
        )
        try ffCheck(ret)
        guard let unwrapped = ctx else { throw FFmpegError.noMemory }

        let initRet = swr_init(unwrapped)
        if initRet < 0 {
            swr_free(&ctx)
            throw FFmpegError(code: initRet)
        }

        self.context = unwrapped
    }

    deinit {
        var ctx: OpaquePointer? = context
        swr_free(&ctx)
    }

    /// Converts audio samples from source to destination frame.
    ///
    /// The destination frame must have its buffers allocated and format/channels set.
    /// Returns the number of samples output per channel.
    @discardableResult
    public func convert(source: borrowing Frame, into destination: inout Frame) throws -> Int32 {
        // swr_convert expects `const uint8_t * const *` for input.
        // extended_data is `UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?`
        // We cast through raw pointer to satisfy the type system.
        let srcRaw = UnsafeRawPointer(source.pointer.pointee.extended_data)
        let srcCast = srcRaw?.assumingMemoryBound(to: UnsafePointer<UInt8>?.self)
        let result = swr_convert(
            context,
            destination.pointer.pointee.extended_data,
            destination.pointer.pointee.nb_samples,
            srcCast,
            source.pointer.pointee.nb_samples
        )
        try ffCheck(result)
        return result
    }

    /// Flushes any remaining buffered samples.
    @discardableResult
    public func flush(into destination: inout Frame) throws -> Int32 {
        let result = swr_convert(
            context,
            destination.pointer.pointee.extended_data,
            destination.pointer.pointee.nb_samples,
            nil,
            0
        )
        try ffCheck(result)
        return result
    }

    /// Returns the delay in the given time base.
    public func delay(sampleRate: Int64) -> Int64 {
        swr_get_delay(context, sampleRate)
    }
}
