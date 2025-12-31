import Testing
@testable import FFmpeg

// MARK: - Format Context Tests

@Test func testFormatContextAllocation() async throws {
    // Test that we can allocate and free a format context
    let formatContext = avformat_alloc_context()
    #expect(formatContext != nil)
    avformat_free_context(formatContext)
}

// MARK: - Packet and Frame Tests

@Test func testPacketAllocation() async throws {
    var packet: UnsafeMutablePointer<AVPacket>? = av_packet_alloc()
    #expect(packet != nil)
    #expect(packet?.pointee.data == nil)
    #expect(packet?.pointee.size == 0)
    av_packet_free(&packet)
    #expect(packet == nil)
}

@Test func testFrameAllocation() async throws {
    var frame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    #expect(frame != nil)
    #expect(frame?.pointee.width == 0)
    #expect(frame?.pointee.height == 0)
    #expect(frame?.pointee.format == -1)  // AV_PIX_FMT_NONE
    av_frame_free(&frame)
    #expect(frame == nil)
}

// MARK: - SwScale Tests

@Test func testSwscaleContextCreation() async throws {
    let srcWidth: Int32 = 1920
    let srcHeight: Int32 = 1080
    let dstWidth: Int32 = 1280
    let dstHeight: Int32 = 720

    let swsContext = sws_getContext(
        srcWidth, srcHeight, AV_PIX_FMT_YUV420P,
        dstWidth, dstHeight, AV_PIX_FMT_RGB24,
        2,  // SWS_BILINEAR = 2
        nil, nil, nil
    )

    #expect(swsContext != nil, "SwScale context should be created")

    if let ctx = swsContext {
        sws_freeContext(ctx)
    }
}

@Test func testSwscaleConversion() async throws {
    let width: Int32 = 320
    let height: Int32 = 240

    // Create source frame (YUV420P)
    var srcFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    guard srcFrame != nil else {
        Issue.record("Failed to allocate source frame")
        return
    }
    defer { av_frame_free(&srcFrame) }

    srcFrame!.pointee.width = width
    srcFrame!.pointee.height = height
    srcFrame!.pointee.format = AV_PIX_FMT_YUV420P.rawValue

    let srcAllocResult = av_frame_get_buffer(srcFrame, 0)
    try FFmpegError.check(srcAllocResult)

    // Fill with test pattern (green in YUV: Y=149, U=43, V=21)
    if let yPlane = srcFrame!.pointee.data.0 {
        memset(yPlane, 149, Int(srcFrame!.pointee.linesize.0 * height))
    }
    if let uPlane = srcFrame!.pointee.data.1 {
        memset(uPlane, 43, Int(srcFrame!.pointee.linesize.1 * height / 2))
    }
    if let vPlane = srcFrame!.pointee.data.2 {
        memset(vPlane, 21, Int(srcFrame!.pointee.linesize.2 * height / 2))
    }

    // Create destination frame (RGB24)
    var dstFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    guard dstFrame != nil else {
        Issue.record("Failed to allocate destination frame")
        return
    }
    defer { av_frame_free(&dstFrame) }

    dstFrame!.pointee.width = width
    dstFrame!.pointee.height = height
    dstFrame!.pointee.format = AV_PIX_FMT_RGB24.rawValue

    let dstAllocResult = av_frame_get_buffer(dstFrame, 0)
    try FFmpegError.check(dstAllocResult)

    // Create SwScale context
    guard let swsContext = sws_getContext(
        width, height, AV_PIX_FMT_YUV420P,
        width, height, AV_PIX_FMT_RGB24,
        2,  // SWS_BILINEAR
        nil, nil, nil
    ) else {
        Issue.record("Failed to create SwScale context")
        return
    }
    defer { sws_freeContext(swsContext) }

    // Perform conversion
    var srcSlice: [UnsafePointer<UInt8>?] = [
        UnsafePointer(srcFrame!.pointee.data.0),
        UnsafePointer(srcFrame!.pointee.data.1),
        UnsafePointer(srcFrame!.pointee.data.2),
        nil
    ]
    var srcStride: [Int32] = [
        srcFrame!.pointee.linesize.0,
        srcFrame!.pointee.linesize.1,
        srcFrame!.pointee.linesize.2,
        0
    ]
    var dstSlice: [UnsafeMutablePointer<UInt8>?] = [
        dstFrame!.pointee.data.0,
        nil, nil, nil
    ]
    var dstStride: [Int32] = [
        dstFrame!.pointee.linesize.0,
        0, 0, 0
    ]

    let scaledHeight = sws_scale(
        swsContext,
        &srcSlice, &srcStride,
        0, height,
        &dstSlice, &dstStride
    )

    #expect(scaledHeight == height, "Should scale all lines")

    // Verify output has data (RGB should be approximately green)
    if let rgbData = dstFrame!.pointee.data.0 {
        let r = rgbData[0]
        let g = rgbData[1]
        let b = rgbData[2]

        // Green in RGB should have high G, low R and B
        #expect(g > r, "Green channel should be higher than red")
        #expect(g > b, "Green channel should be higher than blue")
    }
}

// MARK: - SwResample Tests

@Test func testSwresampleContextCreation() async throws {
    var swrContext: OpaquePointer? = swr_alloc()
    #expect(swrContext != nil)
    swr_free(&swrContext)
    #expect(swrContext == nil)
}

// MARK: - Codec Enumeration Tests

@Test func testEnumerateDecoders() async throws {
    var decoderCount = 0
    var opaque: UnsafeMutableRawPointer?

    while let codec = av_codec_iterate(&opaque) {
        if av_codec_is_decoder(codec) != 0 {
            decoderCount += 1
        }
    }

    #expect(decoderCount > 100, "Should have many decoders available (found: \(decoderCount))")
}

@Test func testEnumerateEncoders() async throws {
    var encoderCount = 0
    var opaque: UnsafeMutableRawPointer?

    while let codec = av_codec_iterate(&opaque) {
        if av_codec_is_encoder(codec) != 0 {
            encoderCount += 1
        }
    }

    #expect(encoderCount > 50, "Should have many encoders available (found: \(encoderCount))")
}

// MARK: - Common Codec Tests

@Test func testCommonVideoCodecs() async throws {
    // H.264
    let h264 = Codec.decoder(for: AV_CODEC_ID_H264)
    #expect(h264 != nil, "H.264 decoder should exist")

    // HEVC/H.265
    let hevc = Codec.decoder(for: AV_CODEC_ID_HEVC)
    #expect(hevc != nil, "HEVC decoder should exist")

    // VP9
    let vp9 = Codec.decoder(for: AV_CODEC_ID_VP9)
    #expect(vp9 != nil, "VP9 decoder should exist")

    // AV1
    let av1 = Codec.decoder(for: AV_CODEC_ID_AV1)
    #expect(av1 != nil, "AV1 decoder should exist")
}

@Test func testCommonAudioCodecs() async throws {
    // AAC
    let aac = Codec.decoder(for: AV_CODEC_ID_AAC)
    #expect(aac != nil, "AAC decoder should exist")

    // MP3
    let mp3 = Codec.decoder(for: AV_CODEC_ID_MP3)
    #expect(mp3 != nil, "MP3 decoder should exist")

    // Opus
    let opus = Codec.decoder(for: AV_CODEC_ID_OPUS)
    #expect(opus != nil, "Opus decoder should exist")

    // FLAC
    let flac = Codec.decoder(for: AV_CODEC_ID_FLAC)
    #expect(flac != nil, "FLAC decoder should exist")
}

// MARK: - Pixel Format Tests

@Test func testPixelFormatDescription() async throws {
    let yuv420p = AV_PIX_FMT_YUV420P
    #expect(yuv420p.description == "yuv420p")

    let rgb24 = AV_PIX_FMT_RGB24
    #expect(rgb24.description == "rgb24")

    let nv12 = AV_PIX_FMT_NV12
    #expect(nv12.description == "nv12")
}

@Test func testPixelFormatLookup() async throws {
    let yuv420p = AVPixelFormat.named("yuv420p")
    #expect(yuv420p == AV_PIX_FMT_YUV420P)

    let rgb24 = AVPixelFormat.named("rgb24")
    #expect(rgb24 == AV_PIX_FMT_RGB24)

    let invalid = AVPixelFormat.named("not_a_format")
    #expect(invalid == AV_PIX_FMT_NONE)
}

// MARK: - Sample Format Tests

@Test func testSampleFormatProperties() async throws {
    let s16 = AV_SAMPLE_FMT_S16
    #expect(s16.description == "s16")
    #expect(s16.bytesPerSample == 2)
    #expect(s16.isPlanar == false)

    let fltp = AV_SAMPLE_FMT_FLTP
    #expect(fltp.description == "fltp")
    #expect(fltp.bytesPerSample == 4)
    #expect(fltp.isPlanar == true)
}

// MARK: - Memory Management Tests

@Test func testFrameBufferReallocation() async throws {
    var frame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    guard frame != nil else {
        Issue.record("Failed to allocate frame")
        return
    }
    defer { av_frame_free(&frame) }

    // First allocation
    frame!.pointee.width = 640
    frame!.pointee.height = 480
    frame!.pointee.format = AV_PIX_FMT_YUV420P.rawValue

    try FFmpegError.check(av_frame_get_buffer(frame, 0))
    #expect(frame!.pointee.data.0 != nil)

    // Unref and reallocate with different size
    av_frame_unref(frame)

    frame!.pointee.width = 1920
    frame!.pointee.height = 1080
    frame!.pointee.format = AV_PIX_FMT_YUV420P.rawValue

    try FFmpegError.check(av_frame_get_buffer(frame, 0))
    #expect(frame!.pointee.data.0 != nil)
    #expect(frame!.pointee.width == 1920)
    #expect(frame!.pointee.height == 1080)
}

// MARK: - Dictionary Tests

@Test func testAVDictionary() async throws {
    var dict: OpaquePointer?
    defer { av_dict_free(&dict) }

    // Set values
    av_dict_set(&dict, "key1", "value1", 0)
    av_dict_set(&dict, "key2", "value2", 0)

    // Get values
    let entry1 = av_dict_get(dict, "key1", nil, 0)
    #expect(entry1 != nil)
    #expect(String(cString: entry1!.pointee.value) == "value1")

    let entry2 = av_dict_get(dict, "key2", nil, 0)
    #expect(entry2 != nil)
    #expect(String(cString: entry2!.pointee.value) == "value2")

    // Count
    #expect(av_dict_count(dict) == 2)
}

// MARK: - Image Utils Tests

@Test func testImageBufferSize() async throws {
    let width: Int32 = 1920
    let height: Int32 = 1080

    // Calculate buffer size for YUV420P
    let yuvSize = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, width, height, 1)
    #expect(yuvSize > 0)
    // YUV420P: Y=1920*1080, U=960*540, V=960*540 = 3110400 bytes
    #expect(yuvSize == width * height * 3 / 2)

    // Calculate buffer size for RGB24
    let rgbSize = av_image_get_buffer_size(AV_PIX_FMT_RGB24, width, height, 1)
    #expect(rgbSize > 0)
    // RGB24: 3 bytes per pixel
    #expect(rgbSize == width * height * 3)
}

// MARK: - Utility Function Tests

@Test func testRescaleTimestamp() async throws {
    // Test av_rescale_q: convert 1 second from milliseconds to microseconds
    let ms_tb = AVRational(num: 1, den: 1000)
    let us_tb = AVRational(num: 1, den: 1000000)

    let result = av_rescale_q(1000, ms_tb, us_tb)  // 1000ms -> us
    #expect(result == 1000000, "1000ms should equal 1000000us")
}

@Test func testGetTimeBase() async throws {
    // AV_TIME_BASE is 1000000 (microseconds)
    #expect(AV_TIME_BASE == 1000000)
}
