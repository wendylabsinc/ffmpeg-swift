import Testing
@testable import FFmpeg

@Test func testVersionStrings() async throws {
    // Verify version strings are formatted correctly (X.Y.Z pattern)
    let avcodecVersion = FFmpegVersion.avcodec
    #expect(avcodecVersion.split(separator: ".").count == 3)

    let avformatVersion = FFmpegVersion.avformat
    #expect(avformatVersion.split(separator: ".").count == 3)

    let avutilVersion = FFmpegVersion.avutil
    #expect(avutilVersion.split(separator: ".").count == 3)

    let swscaleVersion = FFmpegVersion.swscale
    #expect(swscaleVersion.split(separator: ".").count == 3)

    let swresampleVersion = FFmpegVersion.swresample
    #expect(swresampleVersion.split(separator: ".").count == 3)
}

@Test func testConfiguration() async throws {
    let config = FFmpegVersion.configuration
    #expect(!config.isEmpty)
}

@Test func testLicense() async throws {
    let license = FFmpegVersion.license
    #expect(!license.isEmpty)
}
