import Testing
@testable import FFmpeg

@Suite("FFmpeg Library")
struct FFmpegLibraryTests {
    @Test("Version info is non-empty")
    func versionInfo() {
        let version = FFmpegLibrary.avutilVersion
        #expect(!version.isEmpty)
    }

    @Test("avcodec version returns non-zero")
    func avcodecVersion() {
        let version = FFmpegLibrary.avcodecVersion
        #expect(version > 0)
    }

    @Test("avformat version returns non-zero")
    func avformatVersion() {
        let version = FFmpegLibrary.avformatVersion
        #expect(version > 0)
    }

    @Test("Set log level does not crash")
    func setLogLevel() {
        FFmpegLibrary.setLogLevel(.quiet)
        FFmpegLibrary.setLogLevel(.error)
    }
}

@Suite("FFmpegError")
struct FFmpegErrorTests {
    @Test("Error description is non-empty")
    func errorDescription() {
        let error = FFmpegError.eof
        #expect(!error.description.isEmpty)
    }

    @Test("Well-known errors have distinct codes")
    func wellKnownErrors() {
        #expect(FFmpegError.eof != FFmpegError.eagain)
        #expect(FFmpegError.decoderNotFound != FFmpegError.encoderNotFound)
    }

    @Test("ffCheck throws on negative code")
    func ffCheckThrows() {
        #expect(throws: FFmpegError.self) {
            try ffCheck(-1)
        }
    }

    @Test("ffCheck passes on zero")
    func ffCheckPassesZero() throws {
        let result = try ffCheck(0)
        #expect(result == 0)
    }

    @Test("ffCheck passes on positive code")
    func ffCheckPassesPositive() throws {
        let result = try ffCheck(42)
        #expect(result == 42)
    }
}

@Suite("Rational")
struct RationalTests {
    @Test("Double value calculation")
    func doubleValue() {
        let r = Rational(numerator: 1, denominator: 30)
        #expect(abs(r.doubleValue - (1.0 / 30.0)) < 0.0001)
    }

    @Test("Zero denominator returns 0")
    func zeroDenominator() {
        let r = Rational(numerator: 1, denominator: 0)
        #expect(r.doubleValue == 0)
    }

    @Test("Time base constant")
    func timeBase() {
        let tb = Rational.timeBase
        #expect(tb.denominator == 1_000_000)
    }

    @Test("Description format")
    func description() {
        let r = Rational(numerator: 1, denominator: 25)
        #expect(r.description == "1/25")
    }
}

@Suite("Frame")
struct FrameTests {
    @Test("Frame allocation and deallocation")
    func allocAndDealloc() {
        var frame = Frame()
        frame.width = 1920
        frame.height = 1080
        #expect(frame.width == 1920)
        #expect(frame.height == 1080)
        // deinit runs when frame goes out of scope
    }

    @Test("Frame pts assignment")
    func ptsAssignment() {
        var frame = Frame()
        frame.pts = 12345
        #expect(frame.pts == 12345)
    }
}

@Suite("Packet")
struct PacketTests {
    @Test("Packet allocation and deallocation")
    func allocAndDealloc() {
        let packet = Packet()
        #expect(packet.size == 0)
    }

    @Test("Packet stream index")
    func streamIndex() {
        var packet = Packet()
        packet.streamIndex = 3
        #expect(packet.streamIndex == 3)
    }
}

@Suite("AVDictionaryWrapper")
struct AVDictionaryWrapperTests {
    @Test("Set and get")
    func setAndGet() {
        let dict = AVDictionaryWrapper()
        dict.set(key: "title", value: "Hello")
        #expect(dict.get(key: "title") == "Hello")
    }

    @Test("Count")
    func count() {
        let dict = AVDictionaryWrapper()
        dict.set(key: "a", value: "1")
        dict.set(key: "b", value: "2")
        #expect(dict.count == 2)
    }

    @Test("All entries")
    func allEntries() {
        let dict = AVDictionaryWrapper()
        dict.set(key: "x", value: "10")
        dict.set(key: "y", value: "20")
        let entries = dict.allEntries
        #expect(entries["x"] == "10")
        #expect(entries["y"] == "20")
    }

    @Test("Missing key returns nil")
    func missingKey() {
        let dict = AVDictionaryWrapper()
        #expect(dict.get(key: "missing") == nil)
    }
}

@Suite("Codec Discovery")
struct CodecDiscoveryTests {
    @Test("Find H264 decoder by name")
    func findH264Decoder() throws {
        let codec = try Codec.findDecoder(name: "h264")
        let ctx = try CodecContext(codec: codec)
        #expect(ctx.codecType == .video)
    }

    @Test("Find decoder not found throws")
    func findDecoderNotFound() {
        #expect(throws: FFmpegError.self) {
            try Codec.findDecoder(name: "nonexistent_codec_xyz")
        }
    }
}
