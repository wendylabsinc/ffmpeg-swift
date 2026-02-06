import CFFmpegShim

/// Wraps an `AVFilterGraph` for building and running filter chains.
public final class FilterGraph: @unchecked Sendable {
    private var pointer: UnsafeMutablePointer<AVFilterGraph>?
    private var bufferSrcCtx: UnsafeMutablePointer<AVFilterContext>?
    private var bufferSinkCtx: UnsafeMutablePointer<AVFilterContext>?

    public init() throws {
        guard let graph = avfilter_graph_alloc() else {
            throw FFmpegError.noMemory
        }
        self.pointer = graph
    }

    deinit {
        avfilter_graph_free(&pointer)
    }

    /// The underlying graph pointer (non-nil while alive).
    public var graph: UnsafeMutablePointer<AVFilterGraph> {
        pointer!
    }

    /// Configures the filter graph for video filtering.
    ///
    /// - Parameters:
    ///   - filterDescription: The filter string (e.g. "scale=320:240,hflip").
    ///   - width: Input width.
    ///   - height: Input height.
    ///   - pixelFormat: Input pixel format.
    ///   - timeBase: Input time base.
    public func configureVideo(
        filterDescription: String,
        width: Int32,
        height: Int32,
        pixelFormat: AVPixelFormat,
        timeBase: Rational
    ) throws {
        guard let bufferSrc = avfilter_get_by_name("buffer") else {
            throw FFmpegError.filterNotFound
        }
        guard let bufferSink = avfilter_get_by_name("buffersink") else {
            throw FFmpegError.filterNotFound
        }

        let args = "video_size=\(width)x\(height):pix_fmt=\(pixelFormat.rawValue):time_base=\(timeBase.numerator)/\(timeBase.denominator)"

        var srcCtx: UnsafeMutablePointer<AVFilterContext>? = nil
        try ffCheck(avfilter_graph_create_filter(&srcCtx, bufferSrc, "in", args, nil, graph))

        var sinkCtx: UnsafeMutablePointer<AVFilterContext>? = nil
        try ffCheck(avfilter_graph_create_filter(&sinkCtx, bufferSink, "out", nil, nil, graph))

        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        defer {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
        }

        outputs?.pointee.name = av_strdup("in")
        outputs?.pointee.filter_ctx = srcCtx
        outputs?.pointee.pad_idx = 0
        outputs?.pointee.next = nil

        inputs?.pointee.name = av_strdup("out")
        inputs?.pointee.filter_ctx = sinkCtx
        inputs?.pointee.pad_idx = 0
        inputs?.pointee.next = nil

        try ffCheck(avfilter_graph_parse_ptr(graph, filterDescription, &inputs, &outputs, nil))
        try ffCheck(avfilter_graph_config(graph, nil))

        self.bufferSrcCtx = srcCtx
        self.bufferSinkCtx = sinkCtx
    }

    /// Configures the filter graph for audio filtering.
    ///
    /// - Parameters:
    ///   - filterDescription: The filter string (e.g. "aresample=44100,volume=0.5").
    ///   - sampleRate: Input sample rate.
    ///   - sampleFormat: Input sample format.
    ///   - channelLayout: Input channel layout description (e.g. "stereo").
    ///   - timeBase: Input time base.
    public func configureAudio(
        filterDescription: String,
        sampleRate: Int32,
        sampleFormat: AVSampleFormat,
        channelLayout: String,
        timeBase: Rational
    ) throws {
        guard let bufferSrc = avfilter_get_by_name("abuffer") else {
            throw FFmpegError.filterNotFound
        }
        guard let bufferSink = avfilter_get_by_name("abuffersink") else {
            throw FFmpegError.filterNotFound
        }

        let args = "sample_rate=\(sampleRate):sample_fmt=\(String(cString: av_get_sample_fmt_name(sampleFormat))):channel_layout=\(channelLayout):time_base=\(timeBase.numerator)/\(timeBase.denominator)"

        var srcCtx: UnsafeMutablePointer<AVFilterContext>? = nil
        try ffCheck(avfilter_graph_create_filter(&srcCtx, bufferSrc, "in", args, nil, graph))

        var sinkCtx: UnsafeMutablePointer<AVFilterContext>? = nil
        try ffCheck(avfilter_graph_create_filter(&sinkCtx, bufferSink, "out", nil, nil, graph))

        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        defer {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
        }

        outputs?.pointee.name = av_strdup("in")
        outputs?.pointee.filter_ctx = srcCtx
        outputs?.pointee.pad_idx = 0
        outputs?.pointee.next = nil

        inputs?.pointee.name = av_strdup("out")
        inputs?.pointee.filter_ctx = sinkCtx
        inputs?.pointee.pad_idx = 0
        inputs?.pointee.next = nil

        try ffCheck(avfilter_graph_parse_ptr(graph, filterDescription, &inputs, &outputs, nil))
        try ffCheck(avfilter_graph_config(graph, nil))

        self.bufferSrcCtx = srcCtx
        self.bufferSinkCtx = sinkCtx
    }

    /// Pushes a frame into the filter graph's source.
    public func push(frame: borrowing Frame) throws {
        guard let srcCtx = bufferSrcCtx else {
            throw FFmpegError.bug
        }
        try ffCheck(av_buffersrc_add_frame_flags(srcCtx, frame.pointer, Int32(cffmpeg_AV_BUFFERSRC_FLAG_KEEP_REF)))
    }

    /// Pulls a filtered frame from the filter graph's sink.
    ///
    /// Returns `.needsMoreInput` if the filter needs more frames, `.endOfFile` at end.
    public func pull(into frame: inout Frame) throws -> CodecResult {
        guard let sinkCtx = bufferSinkCtx else {
            throw FFmpegError.bug
        }
        let ret = av_buffersink_get_frame(sinkCtx, frame.pointer)
        if ret == cffmpeg_AVERROR_EAGAIN() { return .needsMoreInput }
        if ret == cffmpeg_AVERROR_EOF() { return .endOfFile }
        try ffCheck(ret)
        return .success
    }
}
