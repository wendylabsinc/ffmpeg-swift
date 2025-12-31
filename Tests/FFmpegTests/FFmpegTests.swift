import Testing
@testable import FFmpeg

@Test func testVersionComparable() async throws {
    let v1 = SemanticVersion(major: 1, minor: 0, patch: 0)
    let v2 = SemanticVersion(major: 2, minor: 0, patch: 0)
    let v3 = SemanticVersion(major: 1, minor: 1, patch: 0)

    #expect(v1 < v2)
    #expect(v1 < v3)
    #expect(v2 > v3)
}

@Test func testVersionFromPacked() async throws {
    // FFmpeg packs versions as (major << 16) | (minor << 8) | micro
    let packed: UInt32 = (61 << 16) | (3 << 8) | 100
    let version = SemanticVersion(packed: packed)

    #expect(version.major == 61)
    #expect(version.minor == 3)
    #expect(version.patch == 100)
    #expect(version.description == "61.3.100")
}

@Test func testFFmpegVersions() async throws {
    // Verify version properties return valid versions
    let avcodec = FFmpeg.Versions.avcodec
    #expect(avcodec.major > 0)

    let avformat = FFmpeg.Versions.avformat
    #expect(avformat.major > 0)

    let avutil = FFmpeg.Versions.avutil
    #expect(avutil.major > 0)

    let swscale = FFmpeg.Versions.swscale
    #expect(swscale.major > 0)

    let swresample = FFmpeg.Versions.swresample
    #expect(swresample.major > 0)
}

@Test func testFFmpegConfiguration() async throws {
    let config = FFmpeg.configuration
    #expect(!config.isEmpty)
}

@Test func testFFmpegLicense() async throws {
    let license = FFmpeg.license
    #expect(!license.isEmpty)
    #expect(license.contains("GPL") || license.contains("LGPL"))
}

@Test func testCodecLookup() async throws {
    // H.264 decoder should exist
    let h264Decoder = Codec.decoder(for: AV_CODEC_ID_H264)
    #expect(h264Decoder != nil)
    #expect(h264Decoder?.name == "h264")
    #expect(h264Decoder?.isDecoder == true)

    // AAC decoder should exist
    let aacDecoder = Codec.decoder(named: "aac")
    #expect(aacDecoder != nil)
}

@Test func testFFmpegError() async throws {
    let error = FFmpegError(code: AVERROR_EOF)
    #expect(error.code == AVERROR_EOF)
    #expect(!error.message.isEmpty)
    #expect(error.description.contains("FFmpegError"))
}

@Test func testErrorCheck() async throws {
    // Success case (0 or positive)
    #expect(throws: Never.self) {
        try FFmpegError.check(0)
    }

    // Error case (negative)
    #expect(throws: FFmpegError.self) {
        try FFmpegError.check(AVERROR_EOF)
    }
}
