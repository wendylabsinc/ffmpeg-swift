import CFFmpegShim

/// Wraps `AVFormatContext` for both demuxing (input) and muxing (output).
public final class FormatContext: @unchecked Sendable {
    /// The underlying `AVFormatContext` pointer.
    public let pointer: UnsafeMutablePointer<AVFormatContext>
    private let isOutput: Bool

    // MARK: - Input (Demux)

    /// Opens an input file for demuxing.
    public static func openInput(url: String, options: AVDictionaryWrapper? = nil) throws -> FormatContext {
        var ctx: UnsafeMutablePointer<AVFormatContext>? = nil
        var opts = options?.pointer
        try ffCheck(avformat_open_input(&ctx, url, nil, &opts))
        guard let ctx else { throw FFmpegError.unknown }
        try ffCheck(avformat_find_stream_info(ctx, nil))
        return FormatContext(pointer: ctx, isOutput: false)
    }

    // MARK: - Output (Mux)

    /// Allocates an output context for muxing.
    public static func openOutput(url: String, formatName: String? = nil) throws -> FormatContext {
        var ctx: UnsafeMutablePointer<AVFormatContext>? = nil
        try ffCheck(avformat_alloc_output_context2(&ctx, nil, formatName, url))
        guard let ctx else { throw FFmpegError.unknown }
        return FormatContext(pointer: ctx, isOutput: true)
    }

    private init(pointer: UnsafeMutablePointer<AVFormatContext>, isOutput: Bool) {
        self.pointer = pointer
        self.isOutput = isOutput
    }

    deinit {
        if isOutput {
            if pointer.pointee.pb != nil {
                avio_closep(&pointer.pointee.pb)
            }
            avformat_free_context(pointer)
        } else {
            var ctx: UnsafeMutablePointer<AVFormatContext>? = pointer
            avformat_close_input(&ctx)
        }
    }

    // MARK: - Streams

    /// The number of streams.
    public var streamCount: Int {
        Int(pointer.pointee.nb_streams)
    }

    /// Returns metadata for all streams.
    public var streams: [StreamInfo] {
        (0..<streamCount).map { i in
            StreamInfo(stream: pointer.pointee.streams[i]!)
        }
    }

    /// Returns the stream info at the given index.
    public func stream(at index: Int) -> StreamInfo {
        StreamInfo(stream: pointer.pointee.streams[index]!)
    }

    /// Finds the "best" stream of the given media type.
    public func findBestStream(type: MediaType) throws -> Int32 {
        let index = av_find_best_stream(pointer, type.avValue, -1, -1, nil, 0)
        try ffCheck(index)
        return index
    }

    // MARK: - Duration

    /// Total duration in microseconds, or `nil` if unknown.
    public var duration: Int64? {
        let d = pointer.pointee.duration
        return d == cffmpeg_AV_NOPTS_VALUE ? nil : d
    }

    /// Total duration in seconds.
    public var durationSeconds: Double? {
        guard let d = duration else { return nil }
        return Double(d) / Double(cffmpeg_AV_TIME_BASE)
    }

    // MARK: - Reading packets

    /// Reads the next packet from the input. Returns `nil` at end of file.
    public func readFrame(into packet: inout Packet) throws -> Bool {
        let ret = av_read_frame(pointer, packet.pointer)
        if ret == cffmpeg_AVERROR_EOF() {
            return false
        }
        try ffCheck(ret)
        return true
    }

    /// Seeks to the given timestamp in the given stream.
    public func seek(streamIndex: Int32, timestamp: Int64, flags: Int32 = 0) throws {
        try ffCheck(av_seek_frame(pointer, streamIndex, timestamp, flags))
    }

    // MARK: - Writing (Mux)

    /// Adds a new stream to the output context.
    @discardableResult
    public func addStream(codec: CodecRef? = nil) throws -> StreamHandle {
        guard let stream = avformat_new_stream(pointer, codec?.pointer) else {
            throw FFmpegError.unknown
        }
        return StreamHandle(stream)
    }

    /// Opens the output file for writing (call after configuring streams).
    public func openIO(url: String) throws {
        if (pointer.pointee.oformat.pointee.flags & cffmpeg_AVFMT_NOFILE) == 0 {
            try ffCheck(avio_open(&pointer.pointee.pb, url, cffmpeg_AVIO_FLAG_WRITE))
        }
    }

    /// Writes the file header.
    public func writeHeader(options: AVDictionaryWrapper? = nil) throws {
        var opts = options?.pointer
        try ffCheck(avformat_write_header(pointer, &opts))
    }

    /// Writes an interleaved packet.
    public func writeInterleavedFrame(packet: inout Packet) throws {
        try ffCheck(av_interleaved_write_frame(pointer, packet.pointer))
    }

    /// Writes the file trailer.
    public func writeTrailer() throws {
        try ffCheck(av_write_trailer(pointer))
    }
}
